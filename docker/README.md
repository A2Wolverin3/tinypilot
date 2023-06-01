# TinyPilot in Docker

## Overview

Run Tinypilot in Docker! Using the magic of `docker compose`, tinypilot can be deployed in a containerized manner for both regular and development use. Ansible (and the related 'ansible-role' repositories) is not required.

To run in a Docker container, you obviously need to have the Docker environment installed on your hardware. If you're using Raspberry Pi, you can refer to [this guide](https://pimylifeup.com/raspberry-pi-docker/) for details on how to install Docker on your Pi. You might also consider installing a container management tool as well if you want something more than the usual command-line tools for working with containers. Again, if you're on a Raspberry Pi, here's [another guide](https://pimylifeup.com/raspberry-pi-portainer/) for installing [Portainer](https://www.portainer.io/) on your Pi.

## Normal Deployment

As of today, Tinypilot does not publish containers to a registry. To simply run the latest version of Tinypilot in a container, you'll need to clone/download the git repository:

```sh
git clone https://github.com/tiny-pilot/tinypilot.git
```

From there you just go to the `docker` directory and start the project with compose:

```sh
cd tinypilot/docker
docker compose -f docker-compose.yml -p tinypilot up -d
```

This starts a project named "tinypilot" which builds and deploys containers for the 'tinypilot' and 'ustreamer' roles, as well as a third 'traefik' container that manages routing HTTP traffic to the appropriate container based on URL patterns. Your tinypilot installation is then exposed on port 80 of the host machine.

If you need to stop the service for whatever reason:

```sh
docker compose -p tinypilot stop
```

Or to completely remove the project containers from your Docker host:

```sh
docker compose -p tinypilot down -v
```

> :information_source: By default, the compose file will ask the tinypilot container to initialize the USB Gadget devices necessary for operation. This requires read/write access to configfs (`/sys/kernel/config`) on the host. The container is not otherwise privileged, but that is a significant concession. If you would prefer to manage gadget creation separate from the container, then uncomment the `--no-init` command option at the end of `docker-compose.yml`... then configfs can be used with read-only permissions for a safer deployment

## Developer Deployment

If you're a developer, you probably just want to run the 'tinypilot' role locally while you edit and restart. But you can still deploy a "dev" project which handles the 'ustreamer' and 'traefik' roles and points them back at your host-local instance of the 'tinypilot' role:

```sh
cd tinypilot/docker
docker compose -f docker-compose.dev.yml -p tinypilot-dev up -d
cd ../ansible-role/files
sudo ./init-usb-gadget
cd ../..
./dev-scripts/serve-dev -c ../dev_app_settings.cfg
```

This will start Tinypilot on `localhost:8000` where traefik can direct the non-ustreamer requests. Stop and restart your tinypilot dev server as needed.

Note that before starting tinypilot, there is a call to `init-usb-gadget` to setup the "USB Gadget" devices that tinypilot uses to mimic the Keyboard/Mouse on the target machine. This step does not need to be done every time you start the tinypilot server as these devices are persistent. (You will need to ensure dev_app_settings.cfg - or whatever file you use - has devices properly configured for your dev deployment.)

## Custom Deployment (Or Testing Local Build in Docker)

Finally, developers may want to try their local changes in a Docker environment. To do this, follow the same steps as for a normal deployment... but modify the `docker-compose.yml` file to build the two tinypilot containers from the included `tinypilot-local.Dockerfile` rather than the normal `tinypilot.Dockerfile`. Make sure to remove any existing built tinypilot images from your docker host, as just changing the Dockerfile won't force the image to be updated. Use docker compose `up` and `down` to fully build up and tear down the compose project while iterating.

For iterating on device configurations that don't require a rebuild of the python server or web front-end, you can use the commented volumes in `docker-compose.yml` to run against the live and local versions of those files rather than the copy that is built into the tinypilot image.
