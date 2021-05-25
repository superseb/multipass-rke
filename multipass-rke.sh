#!/usr/bin/env bash

# Configure your settings
# Name for the cluster/configuration files
NAME=""
# Ubuntu image to use (xenial/bionic/focal)
IMAGE="focal"
# Full path, for example, /home/root/.ssh/id_rsa
SSH_PRIVKEYFILE=""
# Full path, for example, /home/root/.ssh/id_rsa.pub
SSH_PUBKEYFILE=""
# If your private key has a passphrase, you can only use ssh-agent to connect to the nodes, set PASSPHRASE to true
SSH_PASSPHRASE=""
# Full path to rke binary (will use `rke` by default, should be in $PATH)
RKE_PATH=""
# How many machines to create
COUNT_MACHINE="1"
# How many CPUs to allocate to each machine
CPU_MACHINE="2"
# How much disk space to allocate to each machine
DISK_MACHINE="10G"
# How much memory to allocate to each machine
MEMORY_MACHINE="4000M"
# Docker version to install
# Bionic only supports Docker 18.03 and higher
DOCKER_VERSION="20.10"

## Nothing to change after this line

# Cloud init template
read -r -d '' CLOUDINIT_TEMPLATE << EOM
#cloud-config
ssh_authorized_keys:
  - __SSH_PUBKEY__

runcmd:
 - '\curl https://releases.rancher.com/install-docker/__DOCKER_VERSION__.sh | sh'
 - '\sudo usermod -a -G docker ubuntu'
EOM

if ! [ -x "$(command -v docker)" >/dev/null 2>&1 ]; then
    if ! [ -x "$(command -v jq)" >/dev/null 2>&1 ]; then
        echo "Docker or jq is needed to parse multipass instance output"
        exit 1
    fi
fi

if ! [ -x "$(command -v multipass)" > /dev/null 2>&1 ]; then
    echo "The multipass binary is not available or not in your \$PATH"
    exit 1
fi

if ! [ -x "$(command -v rke)" > /dev/null 2>&1 ]; then
    if [ -z $RKE_PATH ]; then
        echo "The rke binary needs to be in your \$PATH or \$RKE_PATH needs to be set in the script"
        exit 1
    fi
fi

# Check if name is given or create random string
if [ -z $NAME ]; then
    NAME=$(cat /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | fold -w 6 | head -n 1 | tr '[:upper:]' '[:lower:]')
    echo "No name given, generated name: ${NAME}"
fi

if [ -z $SSH_PRIVKEYFILE ]; then
    # Generate keys
    ssh-keygen -f $NAME-id_rsa -t rsa -b 4096 -N '' >/dev/null 2>&1
    SSH_PRIVKEYFILE=$PWD/$NAME-id_rsa
    SSH_PUBKEYFILE=$PWD/$NAME-id_rsa.pub
    SSH_PASSPHRASE=""
else
    if ! [ -r $SSH_PRIVKEYFILE ]; then
        echo "SSH private key file is not readable (${SSH_PRIVKEYFILE})"
        exit 1
    fi
fi

JQIMAGE=stedolan/jq

echo "Creating cluster ${NAME} with ${COUNT_MACHINE} machines"

# Prepare cloud-init
SSH_PUBKEY=$(cat $SSH_PUBKEYFILE)
echo "$CLOUDINIT_TEMPLATE" | sed -e "s^__SSH_PUBKEY__^$SSH_PUBKEY^" -e "s^__DOCKER_VERSION__^$DOCKER_VERSION^" > "${NAME}-cloud-init.yaml"
echo "Cloud-init is created at ${NAME}-cloud-init.yaml"

for i in $(eval echo "{1..$COUNT_MACHINE}"); do
    echo "Running multipass launch --cpus $CPU_MACHINE --disk $DISK_MACHINE --mem $MEMORY_MACHINE $IMAGE --name rke-$NAME-$i --cloud-init ${NAME}-cloud-init.yaml"
    multipass launch --cpus $CPU_MACHINE --disk $DISK_MACHINE --mem $MEMORY_MACHINE $IMAGE --name rke-$NAME-$i --cloud-init "${NAME}-cloud-init.yaml"
    if [ $? -ne 0 ]; then
        echo "There was an error launching the instance"
        exit 1
    fi
done

for i in $(eval echo "{1..$COUNT_MACHINE}"); do
    echo "Checking Docker on rke-${NAME}-${i}"
    while true; do
        multipass exec rke-$NAME-$i docker version && break
        echo -n "."
        sleep 2
    done
    echo "Docker is available on rke-${NAME}-${i}"
done

# Build RKE config
echo "ssh_key_path: ${SSH_PRIVKEYFILE}" >> "${NAME}-cluster.yml"
echo "nodes:" >> "${NAME}-cluster.yml"

if hash docker >/dev/null 2>&1; then
    multipass list --format json | docker run -e NAME --rm -i $JQIMAGE --arg NAME "$NAME" -r '.list[] | select((.state | contains("Running")) and (.name | contains("rke-" + $NAME))) | "- address: " + .ipv4[0] + "\n  user: ubuntu\n  role: [controlplane,worker,etcd]"' >> "${NAME}-cluster.yml"
else
    multipass list --format json | jq --arg NAME "$NAME" -r '.list[] | select((.state | contains("Running")) and (.name | contains("rke-" + $NAME))) | "- address: " + .ipv4[0] + "\n  user: ubuntu\n  role: [controlplane,worker,etcd]"' >> "${NAME}-cluster.yml"
fi

echo "RKE cluster configuration file is created at ${NAME}-cluster.yml"

if [ -z $RKE_PATH ]; then
  RKE_PATH="rke"
fi

if [ -z $SSH_PASSPHRASE ]; then
    echo "Running rke up --config $NAME-cluster.yml"
    $RKE_PATH --debug up --config $NAME-cluster.yml
else
    echo "Running rke up --config $NAME-cluster.yml --ssh-agent-auth"
    $RKE_PATH --debug up --config $NAME-cluster.yml --ssh-agent-auth
fi

echo "Cluster setup finished"
echo "You can now use the following command to connect to your cluster:"
echo "kubectl --kubeconfig kube_config_${NAME}-cluster.yml get nodes"
