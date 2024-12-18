# LooPIN Containers

This repository contains the Dockerfiles for the LooPIN containers used for our official templates. Resulting containers are available on [Docker Hub].

## Changes

The containers `serverless-automatic` and `sd-auto-abdbarho` have been removed from this repository.

## Container Requirements

### Dependencies

The following dependencies are required as part of LooPIN platform functionality.

- `nginx` - Required for proxying ports to the user.
- `openssh-server` - Required for SSH access to the container.
- 'pip install jupyterlab' - Required for JupyterLab access to the container.

### loopin.yaml

Each container foulder needs to have a loopin.yaml file. This file will contain version info as well as services to be ran. The loopin.yaml file should be formatted as follows:

```yaml
version: '1.0.0'
services:
  - name: 'service1'
    port: 9000
    proxy_port: 9001
  - name: 'service2'
    port: 9002
    proxy_port: 9003
```

### README

Every container folder needs to have its own README.md file, this file will be displayed both on the Docker Hub as well as the README section of the template on the RunPod website. Additionally, if the container is opening a port other than 8888 that is passed through the proxy and the service is not running yet, the README will be displayed to the user.

## Building Containers

buildx bake

```BASH
docker buildx bake

docker buildx bake --push
```


docker build should be ran from the root of the repository, not from the container folder. The build command should be ran as follows:

```bash
docker build -t loopin-docker/<container-name>:<version> -f <container-name>/Dockerfile .
```
