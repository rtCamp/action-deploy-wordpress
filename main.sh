#!/usr/bin/env bash

# Exit on error
set -e

hosts_file="$GITHUB_WORKSPACE/.github/hosts.yml"
export PATH="$PATH:$COMPOSER_HOME/vendor/bin"
export PROJECT_ROOT="$(pwd)"
export HTDOCS="$HOME/htdocs"
export GITHUB_BRANCH=${GITHUB_REF##*heads/}
export CI_SCRIPT_OPTIONS="ci_script_options"
CUSTOM_SCRIPT_DIR="$GITHUB_WORKSPACE/.github/deploy"

function init_checks() {

	# Check if branch is available
	if [[ "$GITHUB_REF" = "" ]]; then
		echo "\$GITHUB_REF is not set"
		exit 1
	fi

	# Check for SSH key if jump host is defined
	if [[ -n "$JUMPHOST_SERVER" ]]; then

		if [[ -z "$SSH_PRIVATE_KEY" ]]; then
			echo "Jump host configuration does not work with vault ssh signing."
			echo "SSH_PRIVATE_KEY secret needs to be added."
			echo "The SSH key should have access to the server as well as jumphost."
			exit 1
		fi
	fi

	# Exit if branch deletion detected
	if [[ "true" == $(jq --raw-output .deleted "$GITHUB_EVENT_PATH") ]]; then
		echo 'Branch deletion trigger found. Skipping deployment.'
		exit 78
	fi
}

function setup_hosts_file() {

	# Setup hosts file
	rsync -av "$hosts_file" /hosts.yml
	cat /hosts.yml
}

function check_branch_in_hosts_file() {

	match=0
	for branch in $(cat "$hosts_file" | shyaml keys); do
		[[ "$GITHUB_REF" = "refs/heads/$branch" ]] &&
			echo "$GITHUB_REF matches refs/heads/$branch" &&
			match=1
	done

	# Exit neutral if no match found
	if [[ "$match" -eq 0 ]]; then
		echo "$GITHUB_REF does not match with any given branch in 'hosts.yml'"
		exit 78
	fi
}

function setup_private_key() {

	if [[ -n "$SSH_PRIVATE_KEY" ]]; then
		echo "$SSH_PRIVATE_KEY" | tr -d '\r' >"$SSH_DIR/id_rsa"
		chmod 600 "$SSH_DIR/id_rsa"
		eval "$(ssh-agent -s)"
		ssh-add "$SSH_DIR/id_rsa"

		if [[ -n "$JUMPHOST_SERVER" ]]; then
			ssh-keyscan -H "$JUMPHOST_SERVER" >>/etc/ssh/known_hosts
		fi
	else
		# Generate a key-pair
		ssh-keygen -t rsa -b 4096 -C "GH-actions-ssh-deploy-key" -f "$HOME/.ssh/id_rsa" -N ""
	fi
}

function maybe_get_ssh_cert_from_vault() {

	# Get signed key from vault
	if [[ -n "$VAULT_GITHUB_TOKEN" ]]; then
		unset VAULT_TOKEN
		vault login -method=github token="$VAULT_GITHUB_TOKEN" >/dev/null
	fi

	if [[ -n "$VAULT_ADDR" ]]; then
		vault write -field=signed_key ssh-client-signer/sign/my-role public_key=@$HOME/.ssh/id_rsa.pub >$HOME/.ssh/signed-cert.pub
	fi
}

function configure_ssh_config() {

	if [[ -z "$JUMPHOST_SERVER" ]]; then
		# Create ssh config file. `~/.ssh/config` does not work.
		cat >/etc/ssh/ssh_config <<EOL
Host $hostname
HostName $hostname
IdentityFile ${SSH_DIR}/signed-cert.pub
IdentityFile ${SSH_DIR}/id_rsa
User $ssh_user
EOL
	else
		# Create ssh config file. `~/.ssh/config` does not work.
		cat >/etc/ssh/ssh_config <<EOL
Host jumphost
	HostName $JUMPHOST_SERVER
	UserKnownHostsFile /etc/ssh/known_hosts
	User $ssh_user

Host $hostname
	HostName $hostname
	ProxyJump jumphost
	UserKnownHostsFile /etc/ssh/known_hosts
	User $ssh_user
EOL
	fi

}

function setup_ssh_access() {

	# get hostname and ssh user
	export hostname=$(cat "$hosts_file" | shyaml get-value "$GITHUB_BRANCH.hostname")
	export ssh_user=$(cat "$hosts_file" | shyaml get-value "$GITHUB_BRANCH.user")

	printf "[\e[0;34mNOTICE\e[0m] Setting up SSH access to server.\n"

	SSH_DIR="$HOME/.ssh"
	mkdir -p "$SSH_DIR"
	chmod 700 "$SSH_DIR"

	setup_private_key
	maybe_get_ssh_cert_from_vault
	configure_ssh_config
}

function maybe_install_submodules() {

	# Check and update submodules if any
	if [[ -f "$GITHUB_WORKSPACE/.gitmodules" ]]; then
		# Change directory ownership to container user due to issue https://github.com/actions/checkout/issues/760
		# This will be changed to www-data or similar on deployment by deployer.
		git config --global --add safe.directory "$GITHUB_WORKSPACE"
		submodule_paths=$(grep path .gitmodules | awk '{print $3}')
		for path in $submodule_paths; do
			git config --global --add safe.directory "$GITHUB_WORKSPACE/$path"
		done

		# add github's public key
		curl -sL https://api.github.com/meta | jq -r '.ssh_keys | .[]' | sed -e 's/^/github.com /' >>/etc/ssh/known_hosts

		identity_file=''
		if [[ -n "$SUBMODULE_DEPLOY_KEY" ]]; then
			echo "$SUBMODULE_DEPLOY_KEY" | tr -d '\r' >"$SSH_DIR/submodule_deploy_key"
			chmod 600 "$SSH_DIR/submodule_deploy_key"
			ssh-add "$SSH_DIR/submodule_deploy_key"
			identity_file="IdentityFile ${SSH_DIR}/submodule_deploy_key"
		fi

		# Setup config file for proper git cloning
		cat >>/etc/ssh/ssh_config <<EOL
Host github.com
HostName github.com
User git
UserKnownHostsFile /etc/ssh/known_hosts
${identity_file}
EOL
		git submodule update --init --recursive
	fi
}

function maybe_install_node_dep() {

	if [[ -n "$NODE_VERSION" ]]; then

		echo "Setting up $NODE_VERSION"
		NVM_LATEST_VER=$(curl -s "https://api.github.com/repos/nvm-sh/nvm/releases/latest" |
			grep '"tag_name":' |
			sed -E 's/.*"([^"]+)".*/\1/') &&
			curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_LATEST_VER/install.sh" | bash
		export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
		[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

		nvm install "$NODE_VERSION"
		nvm use "$NODE_VERSION"

		[[ -z "$NPM_VERSION" ]] && NPM_VERSION="latest" || echo ''
		export npm_install=$NPM_VERSION
		curl -fsSL https://www.npmjs.com/install.sh | bash
	fi
}

function maybe_run_node_build() {

	[[ -n "$NODE_BUILD_DIRECTORY" ]] && cd "$NODE_BUILD_DIRECTORY"
	[[ -n "$NODE_BUILD_COMMAND" ]] && eval "$NODE_BUILD_COMMAND"
	if [[ -n "$NODE_BUILD_SCRIPT" ]]; then
		cd "$GITHUB_WORKSPACE"
		chmod +x "$NODE_BUILD_SCRIPT"
		./"$NODE_BUILD_SCRIPT"
	fi
}

function setup_wordpress_files() {

	mkdir -p "$HTDOCS"
	cd "$HTDOCS"
	export build_root="$(pwd)"

	hosts_wp_version=$(cat "$hosts_file" | shyaml get-value "$GITHUB_BRANCH.WP_VERSION" 2>/dev/null || true)

	# Check if WP_VERSION is already defined in hosts.yml
	# Priority: 1. hosts.yml, 2. workflow file, else use latest
	if [[ -n $hosts_wp_version ]]; then
		WP_VERSION="$hosts_wp_version"
	elif [[ -z $WP_VERSION ]]; then
		WP_VERSION="latest"
	fi

	# If it is integer, add trailing `.0`
	if [[ "$WP_VERSION" =~ ^[+-]?[0-9]+$ ]]; then
		WP_VERSION="$WP_VERSION.0"
	fi

	if [[ "$WP_MINOR_UPDATE" == "true" ]] && [[ "$WP_VERSION" != "latest" ]]; then
		LATEST_MINOR_VERSION=$(
			curl -s "https://api.wordpress.org/core/version-check/1.7/?version=$WP_VERSION" |
				jq -r '[.offers[]|select(.response=="autoupdate")][-1].version'
		)
		MAJOR_DOT_MINOR=$(echo "$WP_VERSION" | cut -c1-3)
		if [[ "$LATEST_MINOR_VERSION" == "$MAJOR_DOT_MINOR"* ]]; then
			WP_VERSION="$LATEST_MINOR_VERSION"
			echo "Using $LATEST_MINOR_VERSION as the latest minor version."
		else
			echo "$WP_VERSION is the latest minor version."
		fi
	fi

	wp core download --version="$WP_VERSION" --allow-root

	rm -r wp-content/

	# Include webroot-files in htdocs if they exists
	if [[ -d "$GITHUB_WORKSPACE/webroot-files" ]]; then
		rsync -av "$GITHUB_WORKSPACE/webroot-files/" "$HTDOCS/" >/dev/null
		rm -rf "$GITHUB_WORKSPACE/webroot-files/"
	fi

	rsync -av "$GITHUB_WORKSPACE/" "$HTDOCS/wp-content/" >/dev/null

	# Remove uploads directory
	cd "$HTDOCS/wp-content/"
	rm -rf uploads

	# Setup mu-plugins if VIP
	if [[ -n "$MU_PLUGINS_URL" ]]; then
		if [[ "$MU_PLUGINS_URL" = "vip" ]]; then
			MU_PLUGINS_URL="https://github.com/Automattic/vip-mu-plugins-public"
		fi
		MU_PLUGINS_DIR="$HTDOCS/wp-content/mu-plugins"
		echo "Cloning mu-plugins from: $MU_PLUGINS_URL"
		git clone -q --recursive --depth=1 "$MU_PLUGINS_URL" "$MU_PLUGINS_DIR"
	fi
}

function deploy() {

	cd "$GITHUB_WORKSPACE"
	dep deploy "$GITHUB_BRANCH"
}

function block_emails() {

	hosts_block_email=$(shyaml get-value "$GITHUB_BRANCH.block_emails" < "$hosts_file" 2>/dev/null || exit 0)

	if [[ -n "$hosts_block_email" ]]; then
		match_hosts_block_email=$(echo "$hosts_block_email" | awk '{$1=$1;print tolower($0)}')
	fi

	if [[ "$match_hosts_block_email" == 'true' ]]; then

		# priority: 1. hosts.yml 2. vip 3. WP
		echo -e "\033[34mSETTING UP EMAIL BLOCKING\033[0m"

		hosts_block_email_dir=$(shyaml get-value "$GITHUB_BRANCH.block_emails_plugin_path" < "$hosts_file" 2>/dev/null || exit 0)

		if [[ -n "$hosts_block_email_dir" ]]; then
			BLOCK_EMAIL_DIR="$HTDOCS/wp-content/$hosts_block_email_dir"
		elif [[ -d "$HTDOCS/wp-content/client-mu-plugins" ]]; then
		   BLOCK_EMAIL_DIR="$HTDOCS/wp-content/client-mu-plugins"
		elif [[ -d "$HTDOCS/wp-content/mu-plugins" ]]; then
		   BLOCK_EMAIL_DIR="$HTDOCS/wp-content/mu-plugins"
		else
		   BLOCK_EMAIL_DIR="$HTDOCS/wp-content/mu-plugins"
		   mkdir -p "$BLOCK_EMAIL_DIR"
		fi

		# remove traling slash
		BLOCK_EMAIL_DIR="${BLOCK_EMAIL_DIR%/}"

		# using this naming convention by default to load this plugin first in mu-plugin loading phase.
		BLOCK_EMAIL_PLUGIN_NAME="000-block-emails.php"

		hosts_block_email_file_name=$(shyaml get-value "$GITHUB_BRANCH.block_emails_plugin_file_name" < "$hosts_file" 2>/dev/null || exit 0)

		if [[ -n "$hosts_block_email_file_name" ]]; then
			BLOCK_EMAIL_PLUGIN_NAME="${hosts_block_email_file_name}.php"
		fi

		BLOCK_EMAIL_PLUGIN_PATH="$BLOCK_EMAIL_DIR/$BLOCK_EMAIL_PLUGIN_NAME"

		if [[ -d "$BLOCK_EMAIL_DIR" ]]; then
			rsync -av  "/000-block-emails.php" "$BLOCK_EMAIL_PLUGIN_PATH"
		echo -e "\033[34mEMAIL BLOCK [ACTIVATED]: $BLOCK_EMAIL_PLUGIN_PATH \033[0m"
		   else
		echo -e "\033[31mEMAIL BLOCK [PATH ERROR]: $BLOCK_EMAIL_DIR doesn't exist.\033[0m"

		fi
	fi

}


function main() {

	init_checks
	if [[ -f "$CUSTOM_SCRIPT_DIR/addon.sh" ]]; then
		source "$CUSTOM_SCRIPT_DIR/addon.sh"
	else
		setup_hosts_file
		check_branch_in_hosts_file
		setup_ssh_access
		maybe_install_node_dep
		maybe_run_node_build
		maybe_install_submodules
		setup_wordpress_files
		block_emails
		deploy
	fi
}

main
