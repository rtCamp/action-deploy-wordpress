This action is a part of [GitHub Actions Library](https://github.com/rtCamp/github-actions-library/) created
by [rtCamp](https://github.com/rtCamp/).

# Deploy WordPress - GitHub Action

[![Project Status: Active – The project has reached a stable, usable state and is being actively developed.](https://www.repostatus.org/badges/latest/active.svg)](https://www.repostatus.org/#active)

A [GitHub Action](https://github.com/features/actions) to deploy WordPress on a server
using [PHP's Deployer.org project](https://deployer.org/).

Please note that, this action expects git repo structure in a certain way. Your webroot should include content
inside `wp-content` except `uploads`. You may use our [WordPress Skeleton](https://github.com/rtCamp/wordpress-skeleton)
as a base, or restructre existing project to fit in.

During deployment, by default this action will download [WordPress](https://wordpress.org/latest.zip), put the content
of the repo in `wp-content` directory and then deploy the entire WordPress setup on the deploy path specified
in `hosts.yml`.

`hosts.yml` is [Deployer's inventory file](https://deployer.org/docs/hosts.html#inventory-file).

## Usage

1. Create a `.github/workflows/deploy.yml` file in your GitHub repo, if one doesn't exist already.
2. Add the following code to the `deploy.yml` file.

```yml
on: push
name: Deploying WordPress Site
jobs:
  deploy:
    name: Deploy
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Deploy
        uses: rtCamp/action-deploy-wordpress@v3
        env:
          SSH_PRIVATE_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
```

3. Create `SSH_PRIVATE_KEY` secret
   using [GitHub Action's Secret](https://developer.github.com/actions/creating-workflows/storing-secrets) and store the
   private key that you use use to ssh to server(s) defined in `hosts.yml`.
4. Create `.github/hosts.yml` inventory file, based
   on [Deployer inventory file](https://deployer.org/docs/hosts.html#inventory-file) format. Make sure you explictly
   define GitHub branch mapping. Only the GitHub branches mapped in `hosts.yml` will be deployed, rest will be filtered
   out. Here is a sample [hosts.yml](https://github.com/rtCamp/wordpress-skeleton/blob/main/.github/hosts.yml).

## Environment Variables

This GitHub action's behavior can be customized using following environment variables:

Variable          | Default | Possible  Values                                                    | Purpose
------------------|---------|---------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
`MU_PLUGINS_URL`  | null    | vip, any git repo url                                               | If value is `vip`, then action will clone [VIP's MU plugins](https://github.com/Automattic/vip-mu-plugins-public) as `mu-plugins` folder. If you want to specifiy a non-VIP mu-plugins repo, you can provide a publicly accessible mu-plugins repo URL as the value.
`WP_VERSION`      | latest  | Any valid WordPress version                                         | If you specify a WordPress version, then that speicifc WordPress version will be downloaded, instead of latest WordPress version. WP_VERSION defined in hosts.yml will have higher priority than one defined in workflow file.
`WP_MINOR_UPDATE` | null    | `true` / `false`                                                    | If set to `true`, latest minor version of `WP_VERSION` will be taken.
`JUMPHOST_SERVER` | null    | Hostname/IP address of the jumphost server                          | If the deployment server is not directly accessible, and needs a jumphost, then this method should be used. (Note: The `SSH_PRIVATE_KEY` env variable should have access to the jumphost as well as deployment server for this to work. Also, this method does not work with vault.)
`SUBMODULE_DEPLOY_KEY` | null    | Read access deploy key created in the submodule repo's deploy keys. | Only required for privated submodule repo. For now only one private submodule deploy key is allowed. All public submodules in repo will be fetched by default without the need of this env variable. (To create a deploy key go to: Settings > Deploy Keys > Add deploy key)
`SKIP_WP_TASKS` | null    | `true`/`false`                                                      | If set to `true`, WordPress specific deplyment tasks will skipped.
`PHP_VERSION` | 7.4      | Valid PHP version                                                   | Determines the cachetool version compatible to use for purging opcache.
`NPM_VERSION`  | null    | Valid NPM Version                                                   | NPM Version. If not specified, latest version will be used.
`NODE_VERSION`  | null    | Valid Node Version                                                  | If not specified, default version built into action will be used.
`NODE_BUILD_DIRECTORY`  | null    | path to valid directory on repository.                              | Build directory. Generally root directory or directory like frontend.
`NODE_BUILD_COMMAND`  | null    | `npm run build` or similar command.                                 | Command used to to build the dependencies needed on deployment.
`NODE_BUILD_SCRIPT`  | null    | path to valid shell script                                          | Custom or predefined script to run after compilation.

All node related variables are completely optional. You can use them if your site needs to have node dependencies built.

## Server Setup

The Deployer.org expects server setup in a particular way.

### Using [EasyEngine](https://easyengine.io/) v4

#### New Site

1. Pass flag `--public-dir=current` during site creation.
2. Delete the `current` folder using `rm -r /opt/easyengine/sites/example.com/app/htdocs/current`.

The `current` folder will be automatically created by Deployer during execution.

#### Existing Site

1. Open file `/opt/easyengine/sites/example.com/config/nginx/conf.d/main.conf`.
2. Replace `/var/www/htdocs` with `/var/www/htdocs/current`.
3. Run `ee site reload example.com`.
4. Move `wp-config.php` to `htdocs`. You can use following command:

```bash
mv /opt/easyengine/sites/example.com/app/wp-config.php /opt/easyengine/sites/example.com/app/htdocs/wp-config.php
```

### Not using EasyEngine

1. Make sure your web server points to `current` subdirectory inside original webroot. Make sure `current` subdirectory
   do NOT exist actually.
2. You may need to reload your webserver.
3. You may need to change location of `wp-config.php` as we need in above section.

## Hashicorp Vault (Optional)

This GitHub action supports [Hashicorp Vault](https://www.vaultproject.io/). This comes in handy if you manage multiple
servers and providing `SSH_PRIVATE_KEY` as GitHub secret per project becomes cumbersome.

To enable Hashicorp Vault support, please define following GitHub secrets:

Variable      | Purpose                                                                       | Example Vaule
--------------|-------------------------------------------------------------------------------|-------------
`VAULT_ADDR`  | [Vault server address](https://www.vaultproject.io/docs/commands/#vault_addr) | `https://example.com:8200`
`VAULT_TOKEN` | [Vault token](https://www.vaultproject.io/docs/concepts/tokens.html)          | `s.gIX5MKov9TUp7iiIqhrP1HgN`

You will need to change `secrets` line in `deploy.yml` file to look like below.

```yml
on: push
name: Deploying WordPress Site using vault
jobs:
  deploy:
    name: Deploy
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Deploy
        uses: rtCamp/action-deploy-wordpress@v3
        env:
          VAULT_ADDR: ${{ secrets.VAULT_ADDR }}
          VAULT_TOKEN: ${{ secrets.VAULT_TOKEN }}
```

GitHub action uses `VAULT_TOKEN` to connect to `VAULT_ADDR` to
retrieve [Signed SSH Certificates](https://www.vaultproject.io/docs/secrets/ssh/signed-ssh-certificates.html#signing-key-amp-role-configuration)
and uses it for deployment.

Please remember that you must configure each of your target deployment server to accept ssh connection via signed
certificate using Vault beforehand. Ususally, you need to run following commands once per server:

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

1. If you would like to completely override this actions deployer recipe. Create a file at
   location `.github/deploy/deploy.php` in your git repository to provide your own [Deployer.org](https://deployer.org/)
   script.
    * Please note that it will completely override this
      action's [original deploy.php](https://github.com/rtCamp/action-deploy-wordpress/blob/master/deploy.php). So if
      you need some portion
      of [original deploy.php](https://github.com/rtCamp/action-deploy-wordpress/blob/master/deploy.php), you need to
      copy that to your own `.github/deploy/deploy.php`.
2. If you need to add one or a few custom tasks on top of this actions `deploy.php`, you can create a file at
   location `.github/deploy/addon.php` in your git repository. Checkout the [example addon.php](./example/addon.php) to
   see how to customize it.
3. If you need to modify the `main.sh` shell script of this action, you can create a file at
   location `.github/deploy/addon.sh` in your git repository. Checkout the [example addon.sh](./example/addon.sh) to see
   how to customize.

## License

[MIT](LICENSE) © 2022 rtCamp

## Does this interest you?

<a href="https://rtcamp.com/"><img src="https://rtcamp.com/wp-content/uploads/2019/04/github-banner@2x.png" alt="Join us at rtCamp, we specialize in providing high performance enterprise WordPress solutions"></a>
