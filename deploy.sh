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

# get hostname
hostname=$(cat "$hosts_file" | shyaml get-value "$GITHUB_BRANCH.hostname")

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
Host $hostname
HostName $hostname
IdentityFile ${SSH_DIR}/signed-cert.pub
IdentityFile ${SSH_DIR}/id_rsa
User root
EOL
fi

# Check and update submodules if any
if [[ -f "$GITHUB_WORKSPACE/.gitmodules" ]]; then
    if [[ -n "$SUBMODULE_DEPLOY_KEY" ]]; then
        echo "$SUBMODULE_DEPLOY_KEY" | tr -d '\r' > "$SSH_DIR/submodule_deploy_key"
        cat >> /etc/ssh/ssh_config <<EOL
Host github.com
HostName github.com
IdentityFile ${SSH_DIR}/submodule_deploy_key
User git
EOL
    fi
    git submodule update --init --recursive
fi

mkdir -p "$HTDOCS"
cd "$HTDOCS"
export build_root="$(pwd)"

WP_VERSION=$(cat "$hosts_file" | shyaml get-value "$CI_SCRIPT_OPTIONS.wp-version" | tr '[:upper:]' '[:lower:]')
wp core download --version="$WP_VERSION" --allow-root

rm -r wp-content/

rsync -av  "$GITHUB_WORKSPACE/" "$HTDOCS/wp-content/"  > /dev/null

# Remove uploads directory
cd "$HTDOCS/wp-content/"
rm -rf uploads

# Setup mu-plugins if VIP
VIP=$(cat "$hosts_file" | shyaml get-value "$CI_SCRIPT_OPTIONS.vip" | tr '[:upper:]' '[:lower:]')
if [ "$VIP" = "true" ]; then
    MU_PLUGINS_URL=${MU_PLUGINS_URL:-"https://github.com/Automattic/vip-mu-plugins-public"}
    MU_PLUGINS_DIR="$HTDOCS/wp-content/mu-plugins"
    echo "Cloning mu-plugins from: $MU_PLUGINS_URL"
    git clone -q --recursive --depth=1 "$MU_PLUGINS_URL" "$MU_PLUGINS_DIR"
fi

cd "$GITHUB_WORKSPACE"
dep deploy "$GITHUB_BRANCH"
