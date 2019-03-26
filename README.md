> **⚠️ Note:** To use this GitHub Action, you must have access to GitHub Actions. GitHub Actions are currently only available in public beta (you must apply for access).

This action is a part of [GitHub Action library](https://github.com/rtCamp/github-actions-library/) created by [rtCamp](https://github.com/rtCamp/).

# Deploy WordPress - GitHub Action

A [GitHub Action](https://github.com/features/actions) to deploy WordPress on a server using [PHP's Deployer.org projec t](https://deployer.org/).

Please note that, this action expects git repo structure in a certain way. Your webroot should include content inside `wp-content` except `uploads`. You may use our [WordPress Skeleton](https://github.com/rtCamp/wordpress-skeleton) as a base, or restructre existing project to fit in.

During deployment, by default this action will download [WordPress](https://wordpress.org/latest.zip), put the content of the repo in `wp-content` directory and then deploy the entire WordPress setup on the deploy path specified in `hosts.yml`.

`hosts.yml` is [Deployer's inventory file](https://deployer.org/docs/hosts.html#inventory-file).

## Usage

1. Create a `.github/main.workflow` in your GitHub repo, if one doesn't exist already.
2. Add the following code to the `main.workflow` file and commit it to the repo's `master` branch.

```bash
workflow "Deploying WordPress Site" {
  resolves = ["Deploy"]
  on = "push"
}

action "Deploy" {
  uses = "rtCamp/action-deploy-wordpress@master"
  secrets = ["SSH_PRIVATE_KEY"]
}
```

3. Create `SSH_PRIVATE_KEY` secret using [GitHub Action's Secret](https://developer.github.com/actions/creating-workflows/storing-secrets) and store the private key that you use use to ssh to server(s) defined in `hosts.yml`.
4. Create `.github/hosts.yml` inventory file, based on [Deployer inventory file](https://deployer.org/docs/hosts.html#inventory-file) format. Make sure you explictly define GitHub branch mapping. Only the GitHub branches mapped in `hosts.yml` will be deployed, rest will be filtered out. Here is a sample [hosts.yml](https://github.com/rtCamp/wordpress-skeleton/blob/master/.github/hosts.yml).


## Environment Variables

This GitHub action's behavior can be customized using following environment variables:

Variable       | Default | Possible  Values            | Purpose
---------------|---------|-----------------------------|----------------------------------------------------
`MU_PLUGINS_URL` | null    | vip, any git repo url         | If value is `vip`, then action will clone [VIP's MU plugins](https://github.com/Automattic/vip-mu-plugins-public) as `mu-plugins` folder. If you want to specifiy a non-VIP mu-plugins repo, you can provide a publicly accessible mu-plugins repo URL as the value.
`WP_VERSION`     | latest  | Any valid WordPress version | If you specify a WordPress version, then that speicifc WordPress version will be downloaded, instead of latest WordPress version.


## Hashicorp Vault (Optional)

This GitHub action supports [Hashicorp Vault](https://www.vaultproject.io/). This comes in handy if you manage multiple servers and providing `SSH_PRIVATE_KEY` as GitHub secret per project becomes cumbersome.

To enable Hashicorp Vault support, please define following GitHub secrets:

Variable      | Purpose                                                                       | Example Vaule
--------------|-------------------------------------------------------------------------------|-------------
`VAULT_ADDR`  | [Vault server address](https://www.vaultproject.io/docs/commands/#vault_addr) | `https://example.com:8200`
`VAULT_TOKEN` | [Vault token](https://www.vaultproject.io/docs/concepts/tokens.html)          | `s.gIX5MKov9TUp7iiIqhrP1HgN`

You will need to change `secrets` line in `main.workflow` file to look like below. 

```bash
workflow "Deploying WordPress Site using vault" {
  resolves = ["Deploy"]
  on = "push"
}

action "Deploy" {
  uses = "rtCamp/action-deploy-wordpress@master"
  secrets = ["VAULT_ADDR", "VAULT_TOKEN"]
}
```

GitHub action uses `VAULT_TOKEN` to connect to `VAULT_ADDR` to retrieve [Signed SSH Certificates](https://www.vaultproject.io/docs/secrets/ssh/signed-ssh-certificates.html#signing-key-amp-role-configuration) and uses it for deployment.

Please remember that you must configure each of your target deployment server to accept ssh connection via signed certificate using Vault beforehand. Ususally, you need to run following commands once per server:

```bash
export VAULT_ADDR='https://example.com:8200'
export VAULT_TOKEN='s.gIX5MKov9TUp7iiIqhrP1HgN'

# Add the public key to all target host's SSH configuration.
curl -o /etc/ssh/trusted-user-ca-keys.pem "$VAULT_ADDR/v1/ssh-client-signer/public_key"

# Add the path where the public key contents are stored to the SSH configuration file as the TrustedUserCAKeys option.
echo "TrustedUserCAKeys /etc/ssh/trusted-user-ca-keys.pem" >> /etc/ssh/sshd_config

# Restart ssh service. This may differ according to the OS.
systemctl restart ssh
```

## Overriding default deployement behavior

Create a file at location `.github/deploy/deploy.php` in your git repo to provide your own [Deployer.org](https://deployer.org/) script. 

Please note that it will completely override this action's [original deploy.php](https://github.com/rtCamp/action-deploy-wordpress/blob/master/deploy.php). So if you need some portion of [original deploy.php](https://github.com/rtCamp/action-deploy-wordpress/blob/master/deploy.php), you need to copy that to your own `.github/deploy/deploy.php`.

## License

[MIT](LICENSE) © 2019 rtCamp
