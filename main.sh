#!/usr/bin/env bash

# Setup hosts file
hosts_file="$GITHUB_WORKSPACE/.github/hosts.yml"
rsync -av "$hosts_file" /hosts.yml
cat /hosts.yml

# Check branch
if [ "$GITHUB_REF" = "" ]; then
    echo "\$GITHUB_REF is not set"
    exit 1
fi

match=0
for branch in $(cat "$hosts_file" | shyaml keys); do
    [[ "$GITHUB_REF" = "refs/heads/$branch" ]] && \
    echo "$GITHUB_REF matches refs/heads/$branch" && \
    match=1
done

# Exit neutral if no match found
if [[ "$match" -eq 0 ]]; then
    echo "$GITHUB_REF does not match with any given branch in 'hosts.yml'"
    exit 78
fi

export PATH="$PATH:$COMPOSER_HOME/vendor/bin"
export PROJECT_ROOT="$(pwd)"
export HTDOCS="$HOME/htdocs"
export GITHUB_BRANCH=${GITHUB_REF##*heads/}
export CI_SCRIPT_OPTIONS="ci_script_options"

printf "[\e[0;34mNOTICE\e[0m] Setting up SSH access to server.\n"

SSH_DIR="$HOME/.ssh"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if [[ -n "$SSH_PRIVATE_KEY" ]]; then
    echo "$SSH_PRIVATE_KEY" | tr -d '\r' > "$SSH_DIR/id_rsa"
    chmod 600 "$SSH_DIR/id_rsa"
    eval "$(ssh-agent -s)"
    ssh-add "$SSH_DIR/id_rsa"
else
    # Generate a key-pair
    ssh-keygen -t rsa -b 4096 -C "GH-actions-ssh-deploy-key" -f "$HOME/.ssh/id_rsa" -N ""
fi

# Get signed key from vault
if [[ -n "$VAULT_GITHUB_TOKEN" ]]; then
    unset VAULT_TOKEN
    vault login -method=github token="$VAULT_GITHUB_TOKEN" > /dev/null
fi

if [[ -n "$VAULT_ADDR" ]]; then
    vault write -field=signed_key ssh-client-signer/sign/my-role public_key=@$HOME/.ssh/id_rsa.pub > $HOME/.ssh/signed-cert.pub

    # Create ssh config file. `~/.ssh/config` does not work.
    cat > /etc/ssh/ssh_config <<EOL
Host *
IdentityFile ${SSH_DIR}/signed-cert.pub
IdentityFile ${SSH_DIR}/id_rsa
User root
EOL
fi

# Check and update submodules if any
if [[ -f "$GITHUB_WORKSPACE/.gitmodules" ]]; then
    # add github's public key
    echo "|1|qPmmP7LVZ7Qbpk7AylmkfR0FApQ=|WUy1WS3F4qcr3R5Sc728778goPw= ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==" >> /etc/ssh/known_hosts

    identity_file=''
    if [[ -n "$SUBMODULE_DEPLOY_KEY" ]]; then
        echo "$SUBMODULE_DEPLOY_KEY" | tr -d '\r' > "$SSH_DIR/submodule_deploy_key"
        chmod 600 "$SSH_DIR/submodule_deploy_key"
        ssh-add "$SSH_DIR/submodule_deploy_key"
        identity_file="IdentityFile ${SSH_DIR}/submodule_deploy_key"
    fi

    # Setup config file for proper git cloning
    cat >> /etc/ssh/ssh_config <<EOL
Host github.com
HostName github.com
User git
UserKnownHostsFile /etc/ssh/known_hosts
${identity_file}
EOL
    git submodule update --init --recursive
fi

mkdir -p "$HTDOCS"
cd "$HTDOCS"
export build_root="$(pwd)"

WP_VERSION=${WP_VERSION:-"latest"}
wp core download --version="$WP_VERSION" --allow-root

rm -r wp-content/

rsync -av  "$GITHUB_WORKSPACE/" "$HTDOCS/wp-content/"  > /dev/null

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

cd "$GITHUB_WORKSPACE"
dep deploy "$GITHUB_BRANCH"
