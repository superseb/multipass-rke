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


## Quickstart Ubuntu 16.04 droplet

```
sudo snap install multipass --beta --classic
wget -O /usr/local/bin/rke https://github.com/$(wget https://github.com/rancher/rke/releases/latest -O - | egrep '/.*/.*/rke_linux-amd64' -o)
chmod +x /usr/local/bin/rke
wget https://raw.githubusercontent.com/superseb/multipass-rke/master/multipass-rke.sh
bash multipass-rke.sh
curl -Lo /usr/local/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x /usr/local/bin/kubectl
kubectl --kubeconfig kube_config_* get nodes
```

## Clean up

The files that are created are:

* `$NAME-cloud-init.yaml`
* `$NAME-cluster.yml`
* `$NAME-id_rsa` (if `SSH_PRIVKEYFILE` is empty)
* `$NAME-id_rsa.pub` (if `SSH_PRIVKEYFILE` is empty)

You can clean up the instances by running `multipass delete rke-$NAME-{1,2,3} --purge` or (**WARNING** this deletes and purges all instances): `multipass delete --all --purge`
