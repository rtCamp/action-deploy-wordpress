#!/usr/bin/env bash

# custom path for files to override default files
custom_path="$GITHUB_WORKSPACE/.github/deploy"
main_script="/deploy.sh"

if [[ -d "$custom_path" ]]; then
    rsync -av "$custom_path/" /
    chmod +x /*.sh
fi

bash "$main_script"
