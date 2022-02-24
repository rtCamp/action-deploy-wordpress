#!/usr/bin/env bash

# Check required env variables
flag=0
if [[ -z "$SSH_PRIVATE_KEY" ]]; then
	flag=1
	missing_secret="SSH_PRIVATE_KEY"
	if [[ -n "$VAULT_ADDR" ]] && [[ -n "$VAULT_TOKEN" ]]; then
		flag=0
	fi
	if [[ -n "$VAULT_ADDR" ]] || [[ -n "$VAULT_TOKEN" ]]; then
		missing_secret="VAULT_ADDR and/or VAULT_TOKEN"
	fi
fi

if [[ "$flag" -eq 1 ]]; then
	printf "[\e[0;31mERROR\e[0m] Secret \`$missing_secret\` is missing. Please add it to this action for proper execution.\nRefer https://github.com/rtCamp/action-deploy-wordpress for more information.\n"
	exit 1
fi

# custom path for files to override default files
custom_path="$GITHUB_WORKSPACE/.github/deploy"
main_script="/main.sh"

if [[ -d "$custom_path" ]]; then
	rsync -av "$custom_path/" /
	chmod +x /*.sh
fi

bash "$main_script"
