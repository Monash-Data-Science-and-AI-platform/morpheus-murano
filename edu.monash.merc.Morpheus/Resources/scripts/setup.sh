#!/bin/bash -xe

API_KEY="$1"
ORG="$2"
PASSWORD="$3"

NAMESPACE=morpheus
USERNAME=ubuntu

# Wait for apt lock to be released
while sudo fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do
  sleep 10
done

# Update the system
export DEBIAN_FRONTEND=noninteractive
apt-get install -q -y unzip snapd tmux

# Install yq
wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
chmod a+x /usr/local/bin/yq

# Install NGC
cd /tmp
wget -q --content-disposition https://ngc.nvidia.com/downloads/ngccli_linux.zip
unzip -qo ngccli_linux.zip
mv /tmp/ngc-cli /opt
ln -s /opt/ngc-cli/ngc /usr/local/bin

# Install microk8s
snap install microk8s --classic --channel=1.24

# Install helm
curl -s https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

if id vagrant >/dev/null 2>&1; then
    USERNAME=vagrant
fi
usermod -a -G microk8s $USERNAME

su - $USERNAME -c "$SHELL +ex" << EOF
    [ -f $HOME/.ngc/config ] || printf "$API_KEY\n\n$ORG\n\n\n" | ngc config set

    # Microk8s setup
    microk8s start
    microk8s kubectl create namespace $NAMESPACE || true
    microk8s kubectl config view --raw > ~/.kube/config
    chmod 600 ~/.kube/config
    microk8s enable dns gpu

    # Fetch helm charts
    cd /tmp
    helm fetch https://helm.ngc.nvidia.com/nvidia/morpheus/charts/morpheus-ai-engine-22.06.tgz --username='\$oauthtoken' --password=$API_KEY --untar
    helm fetch https://helm.ngc.nvidia.com/nvidia/morpheus/charts/morpheus-sdk-client-22.06.tgz --username='\$oauthtoken' --password=$API_KEY --untar
    helm fetch https://helm.ngc.nvidia.com/nvidia/morpheus/charts/morpheus-mlflow-22.06.tgz --username='\$oauthtoken' --password=$API_KEY --untar

    # Start cluster

    # AI ENGINE
    helm upgrade --install --set ngc.apiKey="$API_KEY" --namespace $NAMESPACE ai-engine morpheus-ai-engine

    # SDK 
    # Wait for default service account to spin up
    while microk8s kubectl get sa -n morpheus | grep -q 'No resources found'; do sleep 10; done
    helm upgrade --install --set ngc.apiKey="$API_KEY" --namespace $NAMESPACE helper morpheus-sdk-client

    # MLFLOW
    helm upgrade --install --set ngc.apiKey="$API_KEY" --namespace $NAMESPACE mlflow morpheus-mlflow

    # Return to home directory
    cd /home/ubuntu

    # Download start here
    wget https://raw.githubusercontent.com/Monash-Data-Science-and-AI-platform/morpheus-murano/master/StartHere.ipynb

    # Download and install miniconda
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
    bash Miniconda3-latest-Linux-x86_64.sh -b
    rm Miniconda3-latest-Linux-x86_64.sh

    echo -e "source /home/ubuntu/miniconda3/bin/activate" >> /home/ubuntu/.bashrc
    echo -e "if ! jupyter lab list | grep -q '8888'; then" >> /home/ubuntu/.bashrc
    echo -e "    tmux new-session -d -s jupyter" >> /home/ubuntu/.bashrc
    echo -e "    tmux send -t jupyter \"jupyter lab --port 8888 --no-browser --ServerApp.token='$PASSWORD' --ip='0.0.0.0'\" ENTER" >> /home/ubuntu/.bashrc
    echo -e "fi" >> /home/ubuntu/.bashrc

    tmux new-session -d -s jupyter
    tmux send -t jupyter "source /home/ubuntu/miniconda3/bin/activate; conda install -y -c conda-forge jupyterlab tqdm; jupyter lab --port 8888 --no-browser --ServerApp.token='$PASSWORD' --ip='0.0.0.0'" ENTER
EOF
