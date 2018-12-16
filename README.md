# RKE cluster on multipass instances

This script will create a configurable amount of instances using [multipass](https://github.com/CanonicalLtd/multipass/), create or use specified SSH keys, install a configurable version of Docker on it, create the RKE configuration file (`cluster.yml`) and run RKE (`rke up`) to create the Kubernetes cluster.

## Requirements

* multipass (See [multipass: Getting it](https://github.com/CanonicalLtd/multipass#getting-it))
* RKE (See [rke: latest release](https://github.com/rancher/rke/releases/latest))
* Docker (to run `jq` in a container) or `jq` locally

## Running it

Clone this repo, and run the script:

```
bash multipass-rke.sh
```

This will (defaults):

* Generate random name for your cluster (configurable using `NAME`)
* Generate SSH key for RKE to access the nodes (configurable using `SSH_PRIVKEYFILE`, `SSH_PUBKEYFILE` and `SSH_PASSPHRASE`)
* Create cloud-init to add SSH public key to the machines and install Docker (`17.03` by default, configurable using `DOCKER_VERSION`)
* Create one machine (configurable using `COUNT_MACHINE`) with 1 CPU (`CPU_MACHINE`), 10G disk (`DISK_MACHINE`) and 1500M of memory (`MEMORY_MACHINE`) using Ubuntu xenial (`IMAGE`)
* Create cluster.yml file for RKE
* Run `rke up` to create the cluster
