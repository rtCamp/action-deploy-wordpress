<?php
namespace Deployer;

//adds common necessities for the deployment
require 'recipe/common.php';

set('ssh_type', 'native');
set('ssh_multiplexing', true);

if (file_exists('vendor/deployer/recipes/recipe/rsync.php')) {
	require 'vendor/deployer/recipes/recipe/rsync.php';
} else {
	require getenv('COMPOSER_HOME') . '/vendor/deployer/recipes/recipe/rsync.php';
}

set('shared_dirs', ['wp-content/uploads']);
set('writable_dirs', [
	'wp-content',
	'wp-content/uploads',
]);
inventory('/hosts.yml');

$deployer = Deployer::get();
$hosts = $deployer->hosts;

foreach ($hosts as $host) {
	$host
	->addSshOption('UserKnownHostsFile', '/dev/null')
	->addSshOption('StrictHostKeyChecking', 'no');

	$deployer->hosts->set($host->getHostname(), $host);
}

// Add tests and other directory uncessecary for
// production to exclude block.
set('rsync', [
	'exclude'      => [
		'.git',
		'.github',
		'deploy.php',
		'composer.lock',
		'.env',
		'.env.example',
		'.gitignore',
		'.gitlab-ci.yml',
		'Gruntfile.js',
		'package.json',
		'README.md',
		'gulpfile.js',
		'.circleci',
		'package-lock.json',
		'package.json',
		'phpcs.xml'
	],
	'exclude-file' => true,
	'include'      => [],
	'include-file' => false,
	'filter'       => [],
	'filter-file'  => false,
	'filter-perdir'=> false,
	'flags'        => 'rz', // Recursive, with compress
	'options'      => [ 'delete', 'delete-excluded', 'links', 'no-perms', 'no-owner', 'no-group' ],
	'timeout'      => 300,
]);
set('rsync_src', getenv('build_root'));
set('rsync_dest', '{{release_path}}');


/*  custom task defination    */
desc('Download cachetool');
task('cachetool:download', function () {
	# Using 5.x for PHP >=7.2 compatibility
	run('wget https://github.com/gordalina/cachetool/releases/download/5.1.3/cachetool.phar -O {{release_path}}/cachetool.phar');
});

/*  custom task defination    */
desc('Reset opcache');
task('opcache:reset', function () {

	$ee_version = '';
	try {
		$ee_version = run('ee --version');
	} catch(\Exception $e) {
		echo 'Not using EasyEngine.';
	}

	if ( false !== strpos( $ee_version, 'EasyEngine v3' ) ) {

		$output = run('php {{release_path}}/cachetool.phar opcache:reset --fcgi=127.0.0.1:9070');

	} elseif ( false !== strpos( $ee_version, 'EE 4' ) ) {

		cd( '{{deploy_path}}' );
		$output = run( 'ee shell --command="php current/cachetool.phar opcache:reset --fcgi=127.0.0.1:9000" --skip-tty' );

	} else {
		echo 'Skipping opcache reset as EasyEnigne is not installed.';
	}

	writeln('<info>' . $output . '</info>');

});

desc('Upgrade WordPress DB');
task('core_db:update', function () {

	$ee_version = '';
	try {
		$ee_version = run('ee --version');
	} catch(\Exception $e) {
		echo 'Not using EasyEngine.';
	}

	if ( false !== strpos( $ee_version, 'EasyEngine v3' ) ) {

		$output = run('cd {{release_path}} && wp core update-db');

	} elseif ( false !== strpos( $ee_version, 'EE 4' ) ) {

		cd( '{{deploy_path}}' );
		$output = run( 'cd current && ee shell --command="wp core update-db" --skip-tty' );

	} else {
		echo 'Skipping WordPress db core update as EasyEnigne is not installed.';
	}

	writeln('<info>' . $output . '</info>');

});

desc('Symlink wp-config.php');
task('wp:config', function () {
	run('[ ! -f {{release_path}}/../wp-config.php ] && cd {{release_path}}/../ && ln -sn ../wp-config.php && echo "Created Symlink for wp-config.php." || echo ""');
});

/*
 * Change permissions to 'www-data' for 'current/',
 * so that 'wp-cli' can read/write files.
 */
desc('Correct Permissions');
task('permissions:set', function () {

	try {
		$plesk_version = run('plesk version');
	} catch(\Exception $e) {
		echo 'Not using Plesk.';
	}

	if ( false !== strpos( $plesk_version, 'Plesk' ) ) {
		$branch       = get('branch');
		$hosts_parsed = yaml_parse_file("/hosts.yml");
		$permission   = ($hosts_parsed[$branch]['permission']);

		$output       = run("chown -R $permission {{deploy_path}}");
		writeln('<info>' . $output . '</info>');
		$output = run("chmod o-rwx {{deploy_path}}/current");
		writeln('<info>' . $output . '</info>');
	} else {
		$output = run('chown -R www-data:www-data {{deploy_path}}');
		writeln('<info>' . $output . '</info>');
	}
});

/*   deployment task   */
desc('Deploy the project');
task('deploy', [
	'deploy:prepare',
	'deploy:unlock',
	'deploy:lock',
	'deploy:release',
	'rsync',
	'wp:config',
	'cachetool:download',
	'deploy:shared',
	'deploy:symlink',
	'permissions:set',
	'opcache:reset',
	'core_db:update',
	'deploy:unlock',
	'cleanup'
]);
after('deploy', 'success');
