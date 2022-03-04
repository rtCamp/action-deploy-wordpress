#!/usr/bin/env bash

function some_custom_function() {
	# function logic goes here.
	echo 'Custom logic goes here'
}

# Overriding the main function of `main.sh`.
# This is compulsory. You can take the functions that are run
# in `main.sh`'s `main` functions else condition and
# add edit/remove them as well as add your function
# where needed for custom deployment changes.
function main() {
	setup_hosts_file
	check_branch_in_hosts_file
	setup_ssh_access
	maybe_install_node_dep
	maybe_run_node_build
	maybe_install_submodules
	some_custom_function # Adding the custom function in the order where needed.
	setup_wordpress_files
	deploy
}

main
