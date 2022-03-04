<?php

namespace Deployer;

/**
 * Define your custom tasks as shown below.
 */
desc( 'Some task' );
task( 'some:task', function () {
	// task code here.
} );


desc( 'Some other task' );
task( 'some:othertask', function () {
	// task code here.
} );

/**
 * Update the tasks variable and add your tasks in the order where they should be.
 * You can also remove any tasks which you may not need.
 */
$tasks = [
	'deploy:prepare',
	'deploy:unlock',
	'deploy:lock',
	'deploy:release',
	'rsync',
	'wp:config',
	'some:task', // Adding custom task in $tasks variable.
	'some:othertask', // Adding custom task in $tasks variable.
	'cachetool:download',
	'deploy:shared',
	'deploy:symlink',
	'permissions:set',
	'opcache:reset',
	'core_db:update',
	'deploy:unlock',
	'cleanup',
];

// Stop editing now. The above given tasks will be run by deploy.php of this action now.
