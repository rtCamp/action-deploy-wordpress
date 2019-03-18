# WordPress Deploy - GitHub Action

1. A [GitHub Action](https://github.com/features/actions) that can be used to deploy a WordPress site using [Deployer](https://deployer.org/).
2. This action can be used when you have the contents of `wp-content` folder in root of your repository. [This](https://github.com/rtCamp/github-actions-wordpress-skeleton) is how a skeleton repo would look like. 
3. During deployment, by default this action will download [WordPress](https://wordpress.org/latest.zip), put the content of the repo in `wp-content` directory and then deploy the entire WordPress setup on the deploy path specified in `hosts.yml`. 

## Installation

>To use this GitHub Action, you must have access to GitHub Actions. GitHub Actions are currently only available in public beta (you must [apply for access](https://github.com/features/actions)).

You can use this action after any other action to deploy the files of your repo to WordPress site. Here is an example setup of this action:

1. Create a `.github/main.workflow` in your GitHub repo.
2. Create `.github/hosts.yml` inventory file, which is a standard [Deployer inventory file](https://deployer.org/docs/hosts.html#inventory-file), to map the details of deployments. 
3. Here is a sample minimal [hosts.yml](https://github.com/rtCamp/github-actions-wordpress-skeleton/blob/master/.github/hosts.yml) required for deployment. Additional `ci_script_options` config block is required for this action as defined in the [sample](https://github.com/rtCamp/github-actions-wordpress-skeleton/blob/master/.github/hosts.yml) for customisations.
4. Add the following code to the `main.workflow` file and commit it to the repo's `master` branch.

```bash
workflow "Deploying WordPress Site" {
  resolves = ["Deploy"]
  on = "push"
}

action "Deploy" {
  uses = "rtCamp/action-wordpress-deploy@master"
  secrets = ["SSH_PRIVATE_KEY"]
}
```

5. Define `SSH_PRIVATE_KEY` as a [GitHub Actions Secret](https://developer.github.com/actions/creating-workflows/storing-secrets) with the private key that can ssh to server(s) defined in `hosts.yml`. (You can add secrets using the visual workflow editor or the repository settings.)
6. Whenever you commit, this action will run.


## Environment Variables

```shell
# MU plugins git repository url in case the site is VIP (defined in hosts.yml). Default is set to: https://github.com/Automattic/vip-mu-plugins-public
MU_PLUGINS_URL="https://github.com/Automattic/vip-mu-plugins-public"
```

## Additional Supported SSH Deployment Methods

### Vault

1. The setup of ssh keys for deployment is supported through [vault](https://www.vaultproject.io/). `VAULT_ADDR` secret variable specifies the address on which vault is deployed, e.g., `VAULT_ADDR=https://example.com:8200`. [VAULT_TOKEN](https://www.vaultproject.io/docs/concepts/tokens.html) is the token by which authentication with vault will be possible to retrieve the secrets and information.

2. For Signed SSH Certificates to work, follow the steps give [here](https://www.vaultproject.io/docs/secrets/ssh/signed-ssh-certificates.html#signing-key-amp-role-configuration) on the deployed vault instance.

3. Then, to configure the server to accept ssh connection via signed certificate, run the following steps:
```bash
export VAULT_ADDR='https://example.com:8200'
export VAULT_TOKEN='vault-token'

# Add the public key to all target host's SSH configuration.
curl -o /etc/ssh/trusted-user-ca-keys.pem "$VAULT_ADDR/v1/ssh-client-signer/public_key"

# Add the path where the public key contents are stored to the SSH configuration file as the TrustedUserCAKeys option.
echo "TrustedUserCAKeys /etc/ssh/trusted-user-ca-keys.pem" >> /etc/ssh/sshd_config

# Restart ssh service. This may differ according to the OS.
systemctl restart ssh
```

### Usage

1. Using vault token

```bash
workflow "Deploying WordPress Site using vault" {
  resolves = ["Deploy"]
  on = "push"
}

action "Deploy" {
  uses = "rtCamp/action-wordpress-deploy@master"
  secrets = ["VAULT_ADDR", "VAULT_TOKEN"]
}
```

2. Using vault GitHub login method. (The token should have `read: org` permission and then it should be setup in secret variable `VAULT_GITHUB_TOKEN`.)

```bash
workflow "Deploying WordPress Site using vault" {
  resolves = ["Deploy"]
  on = "push"
}

action "Deploy" {
  uses = "rtCamp/action-wordpress-deploy@master"
  secrets = ["VAULT_ADDR", "VAULT_GITHUB_TOKEN"]
}
```

## Customize the action

Any file kept inside `.github/deploy` folder of a project's repo which is present in this repo as well will be taken during the build run and respected while running this action.

For example, if you needed something custom in `deploy.php` for some project's deployment here is what you would do:

1. Take a reference of [this deploy.php](https://github.com/rtCamp/action-wordpress-deploy/blob/master/deploy.php) and create similar `deploy.php` with additional configurations as per need.
2. Place it in location `.github/deploy/deploy.php` of the project's repo.

That's it! That `deploy.php` will be respected in all deployments of that project.

## License

[MIT](LICENSE) © 2019 rtCamp
