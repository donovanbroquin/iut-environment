# Weather production

This repository contains a Docker Compose way to host your Weather app and static websites.

This guide assumes you are using an Ubuntu VM. If you want to use something else, check the appropriate documentation.

> Of course, you need to know basic stuff about Linux

## CI / CD

A [GitHub Workflow](https://docs.github.com/en/actions/writing-workflows) that builds your application Docker image and stores it in GHCR is present in the `production` directory.

GHCR is the GitHub equivalent of the DockerHub.

> This step is mandatory for the following

- create a token 
    - Your avatar > Settings > Developer Settings > Personal access tokens > Tokens (classic) > Generate new token > Generate new token (classic)
    - select **write:packages** / **read:packages** / **delete:packages**
- in your repository, go to Settings > Secrets and variables > Actions > New repository secret
    - name it GHCR_TOKEN
    - past the previously generated token
- put the `build_weather_production_image.yml` in your project to `.github/workflows`
- put the `dockerfile.server.production` and `Caddyfile` in your project
    - it supposed your application is in a laravel directory
    - if not, you can adjust the dockerfile by changing `./laravel` to `.`
- push to `main`

The workflow probably take at least 3 minutes.

By default, the workflow will create the image with a tag like `ghcr.io/<YOUR_USERNAME>/iut-weather:latest` for `amd64 (x64)` so be sure to **use this architecture on your server**.

You can see it under Your avatar > Your profile > Packages > iut-weather

## Server
The guide assumes you have a server somewhere ([Hetzner](https://www.hetzner.com/), [Digital Ocean](https://www.digitalocean.com/), [AWS](https://aws.amazon.com/fr/), ...) with a user which can use `sudo`.

### Root user
If you only have root access, you **really** should create another user and disable root login for security reasons.

The `create_user.sh` script can help you with that.

Once the user is created, use it only.

### Ports restriction

Ensure your server does not allow connection from any port but the one you need.
If you plan to do only web you can keep the following ports open:

- 22: SSH
- 80: HTTP
- 443: HTTPS

Some providers like Hetzner have a firewall in their console. 

If the one you choose does not have this feature, you can do it using [UFW](https://doc.ubuntu-fr.org/ufw) following this [tutorial](https://www.digitalocean.com/community/tutorials/ufw-essentials-common-firewall-rules-and-commands)

### Fail2Ban
[Fail2Ban](https://doc.ubuntu-fr.org/fail2ban) is a console app that blacklists IPs trying too much to connect to a server.

You can install following this [tutorial](https://www.digitalocean.com/community/tutorials/how-to-protect-ssh-with-fail2ban-on-ubuntu-22-04)

## Install Docker
The Docker installation can be resumed as those commands:

```bash
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
 "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
 $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
 sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

# Install docker itself
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Allow you user to use Docker without sudo
sudo usermod -aG docker <USERNAME>
```

Once it is done, quit your SSH connection and make a new one to ensure the changes have been applied.

You should be able to test it with the following.
```bash
docker run hello-world
```
> If you get `Hello from Docker! This message shows that your installation appears to be working correctly.` everything is ok.

## Deploy
In the production directory, you can see `compose.production.yml` and `.env.example` files. 

Those files must be put in the server, at any place you want but **in the same directory**

### Docker Compose environment
The `.env.example` must be renamed as `.env` in the server. 

Also, you need to fill it with your data.

|Name|Description|
|----|-----------|
|LETSENCRYPT_MAIL| Let's encrypt require an email to generate a valid certificate|
|WEATHER_WEB_IMAGE| Your Docker app image tag (ex: ghcr.io/<GITHUB_USERNAME>/iut-weather:latest)|
|WEATHER_DOMAIN| Your application domain without HTTP(s)://|
|PORTFOLIO_IMAGE| Your Docker portfolio image tag (ex: ghcr.io/<GITHUB_USERNAME>/portfolio:latest)|
|PORTFOLIO_DOMAIN| Your portfolio domain without HTTP(s)://|

### Containers
This compose will create three containers by default:

- [traefik](https://doc.traefik.io/traefik/): a [proxy](https://fr.wikipedia.org/wiki/Proxy) in charge of redirecting the user to the right container through the 80 or 443 port. Also, it generates your SSL certificates using [Let's Encrypt](https://letsencrypt.org/fr/)
- weather: your application
- portfolio: your static portfolio website

> Feel free to change it as you need

### Weather

#### Build
Copy the following files: 
- build_weather_production.yml: `<PROJECT>/.github/workflows/`
- dockerfile.server.production: `<PROJECT>/`
- Caddyfile: `<PROJECT>/`

The CI will be triggered every time you push to the `main` branch. If you need it, you can [manually trigger](https://docs.github.com/en/actions/managing-workflow-runs-and-deployments/managing-workflow-runs/manually-running-a-workflow) the build.

> On local, you can build the image with `docker build -t weather-server .`

#### Environment
Laravel applications need some environment variables to work. The simplest way is to copy a full Laravel `.env` file on the server in the same directory as the `compose.production.yml` and name it `.env.weather`

#### Database
Since the database used by the application is an sqlite one, you need to create a `database.sqlite` file in the **same directory as the compose file** and update the rights to be able to access it if needed.

```
touch database.sqlite
chmod o+rw database.sqlite
```

### Portfolio
Once you have created your portfolio Docker image, you can use the tag you want by setting it in the `.env` at the **same level** as the `compose.production.yml`

> By default, the tag is :latest

#### Build
Copy the following files: 
- dockerfile.static.production: `<PROJECT>/`

The CI will be triggered every time you push to the `main` branch. If you need it, you can [manually trigger](https://docs.github.com/en/actions/managing-workflow-runs-and-deployments/managing-workflow-runs/manually-running-a-workflow) the build.

> On local, you can build the image with `docker build -t portfolio .`

#### Assets
If the JavaScript or the CSS does not load, check the path you use in your HTML.

### Launch / Stop
You can launch or stop your containers using the following commands

```bash
# Start
docker compose -f compose.production up -d

# Stop
docker compose -f compose.production up -d
```

> When you deploy a new app or an update, you should stop all containers and start them again using the command to ensure everything has been taken correctly

This is a basic way to launch containers. In this case, any update involves all application downtime but you are not running a heavy workload on it so if you deploy by the afternoon end, no one should see it 😉
