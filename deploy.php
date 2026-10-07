<?php

namespace Deployer;

// adds common necessities for the deployment.
require 'recipe/common.php';

set( 'ssh_multiplexing', true );
// Deployer 7 raised the default from 5 to 10; keep the v6-era behavior so
// server disk usage doesn't double for existing sites.
set( 'keep_releases', 5 );

// Deployer 7 numbers releases from .dep/latest_release. Two states break a
// naive read of that file: Deployer 6 never wrote it (existing v6 sites have
// numbered release dirs but no counter), and a deploy that dies after mkdir
// releases/N but before persisting the counter leaves it stale at N-1. Both
// would collide on the next deploy with "Release name already exists", so
// reconcile the counter against the highest numbered directory in releases/
// and take whichever is greater.
set( 'release_name', function () {
	return within( '{{deploy_path}}', function () {
		$counter = test( '[ -f .dep/latest_release ]' ) ? intval( run( 'cat .dep/latest_release' ) ) : 0;
		$highest = intval( run( "ls -1 releases 2>/dev/null | grep -E '^[0-9]+$' | sort -n | tail -n 1 || echo 0" ) );
		return strval( max( $counter, $highest ) + 1 );
	} );
} );
set( 'ssh_arguments', [ '-o UserKnownHostsFile=/dev/null', '-o StrictHostKeyChecking=no' ] );

if ( file_exists( 'vendor/deployer/deployer/contrib/rsync.php' ) ) {
	require 'vendor/deployer/deployer/contrib/rsync.php';
} else {
	require getenv( 'COMPOSER_HOME' ) . '/vendor/deployer/deployer/contrib/rsync.php';
}

set( 'shared_dirs', [ 'wp-content/uploads' ] );
set( 'writable_dirs', [
	'wp-content',
	'wp-content/uploads',
] );
import( '/hosts.yml' );

// Add tests and other directory unnecessary things for
// production to exclude block.
set( 'rsync', [
	'exclude'       => [
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
		'gulpfile.js',
		'.circleci',
		'package-lock.json',
		'package.json',
		'phpcs.xml',
		'llms.txt',
	],
	'exclude-file'  => true,
	'include'       => [],
	'include-file'  => false,
	'filter'        => [],
	'filter-file'   => false,
	'filter-perdir' => false,
	'flags'         => 'rz', // Recursive, with compress
	'options'       => [ 'delete', 'delete-excluded', 'links', 'no-perms', 'no-owner', 'no-group' ],
	'timeout'       => 300,
] );

set( 'rsync_src', getenv( 'build_root' ) );
set( 'rsync_dest', '{{release_path}}' );


/*  custom task defination    */
desc( 'Download cachetool' );
task( 'cachetool:download', function () {

	$php_version = getenv( 'PHP_VERSION' );
	if ( empty( $php_version ) ) {
		$ee_version = '';
		try {
			$ee_version = run( 'ee --version' );
		} catch ( \Exception $e ) {
			echo 'Not using EasyEngine.';
		}

		if ( false !== strpos( $ee_version, 'EE 4' ) ) {
			try {
				$php_version = run( 'cd {{deploy_path}} && ee shell --command="php -r \'echo PHP_MAJOR_VERSION;\'" --skip-tty' );
			} catch ( \Exception $e ) {
				echo 'Could not determine PHP version. Use `PHP_VERSION` env variable to specify the version.';
				echo 'Falling back to version 7.4 as default';
				$php_version = 7.4;
			}
		}
	}

	if ( $php_version < 8 ) {
		# Using 5.x for PHP >=7.2 compatibility
		run( 'wget https://github.com/gordalina/cachetool/releases/download/5.1.3/cachetool.phar -O {{release_path}}/cachetool.phar' );
	} else {
		run( 'wget https://github.com/gordalina/cachetool/releases/download/8.4.0/cachetool.phar -O {{release_path}}/cachetool.phar' );
	}
} );

/*  custom task defination    */
desc( 'Reset opcache' );
task( 'opcache:reset', function () {

	$ee_version = '';
	try {
		$ee_version = run( 'ee --version' );
	} catch ( \Exception $e ) {
		echo 'Not using EasyEngine.';
	}

	$output = '';
	if ( false !== strpos( $ee_version, 'EasyEngine v3' ) ) {

		$output = run( 'php {{release_path}}/cachetool.phar opcache:reset --fcgi=127.0.0.1:9070' );

	} elseif ( false !== strpos( $ee_version, 'EE 4' ) ) {

		cd( '{{deploy_path}}' );
		$output = run( 'ee shell --command="php current/cachetool.phar opcache:reset --fcgi=127.0.0.1:9000" --skip-tty' );

	} else {
		echo 'Skipping opcache reset as EasyEnigne is not installed.';
	}

	writeln( '<info>' . $output . '</info>' );

} );

desc( 'Upgrade WordPress DB' );
task( 'core_db:update', function () {

	$ee_version = '';
	try {
		$ee_version = run( 'ee --version' );
	} catch ( \Exception $e ) {
		echo 'Not using EasyEngine.';
	}

	$output = '';
	if ( false !== strpos( $ee_version, 'EasyEngine v3' ) ) {

		$output = run( 'cd {{release_path}} && wp core update-db' );

	} elseif ( false !== strpos( $ee_version, 'EE 4' ) ) {

		cd( '{{deploy_path}}' );
		$output = run( 'cd current && ee shell --command="wp core update-db" --skip-tty' );

	} else {
		echo 'Skipping WordPress db core update as EasyEnigne is not installed.';
	}

	writeln( '<info>' . $output . '</info>' );

} );

desc( 'Symlink wp-config.php' );
task( 'wp:config', function () {

	run( '[ ! -f {{release_path}}/../wp-config.php ] && cd {{release_path}}/../ && ln -sn ../wp-config.php && echo "Created Symlink for wp-config.php." || echo ""' );
} );

/*
 * Change permissions to 'www-data' for 'current/',
 * so that 'wp-cli' can read/write files.
 */
desc( 'Correct Permissions' );
task( 'permissions:set', function () {

	$output = run( 'chown -R www-data:www-data {{deploy_path}}' );
	writeln( '<info>' . $output . '</info>' );

} );

desc( 'Symlink llms.txt from shared if it exists' );
task( 'llms:link', function () {
	if ( test( '[ -f "{{deploy_path}}/shared/llms.txt" ]' ) ) {
		run( '{{bin/symlink}} "{{deploy_path}}/shared/llms.txt" "{{release_path}}/llms.txt"' );
	}
} );

after( 'deploy:shared', 'llms:link' );

$wp_tasks = [
	// Deployer 7's deploy:prepare is a group task that runs deploy:update_code
	// (fails without a 'repository' config — this action deploys via rsync)
	// and duplicates lock/release/shared, so its sub-tasks are listed
	// explicitly instead.
	'deploy:info',
	'deploy:setup',
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
	'deploy:cleanup',
];

$non_wp_tasks = [
	'deploy:info',
	'deploy:setup',
	'deploy:unlock',
	'deploy:lock',
	'deploy:release',
	'rsync',
	'deploy:shared',
	'deploy:symlink',
	'deploy:unlock',
	'deploy:cleanup',
];

if ( 'true' === getenv( 'SKIP_WP_TASKS' ) ) {
	$tasks = $non_wp_tasks;
} else {
	$tasks = $wp_tasks;
}

$addon_recipe = getenv( 'GITHUB_WORKSPACE' ) . '/.github/deploy/addon.php';
if ( file_exists( $addon_recipe ) ) {
	require $addon_recipe;
}

/*   deployment task   */
desc( 'Deploy the project' );
task( 'deploy', $tasks );
after( 'deploy', 'deploy:success' );
