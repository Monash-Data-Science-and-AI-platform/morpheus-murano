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
apt-get install -q -y unzip snapd

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


cat << EOF > /tmp/jupyter-service.yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/name: sdk-cli-{{ .Release.Name }}
    app.kubernetes.io/instance: {{ .Release.Name }}
  name: jupyter-lab
spec:
  type: NodePort
  ports:
  - name: sdk-cli-helper
    port: 8888
    targetPort: 8888
    nodePort: 30888
    protocol: TCP
  selector:
    app.kubernetes.io/name: sdk-cli-{{ .Release.Name }}
    app.kubernetes.io/instance: {{ .Release.Name }}
EOF

su - $USERNAME -c "$SHELL +ex" << EOF
    [ -f $HOME/.ngc/config ] || printf "$API_KEY\n\n$ORG\n\n\n" | ngc config set

    # Microk8s setup
    microk8s start
    microk8s kubectl create namespace $NAMESPACE || true
    microk8s enable dns
    microk8s kubectl config view --raw > ~/.kube/config
    chmod 600 ~/.kube/config

    # Fetch helm charts
    cd /tmp
    helm fetch https://helm.ngc.nvidia.com/nvidia/morpheus/charts/morpheus-ai-engine-22.06.tgz --username='\$oauthtoken' --password=$API_KEY --untar
    helm fetch https://helm.ngc.nvidia.com/nvidia/morpheus/charts/morpheus-sdk-client-22.06.tgz --username='\$oauthtoken' --password=$API_KEY --untar
    helm fetch https://helm.ngc.nvidia.com/nvidia/morpheus/charts/morpheus-mlflow-22.06.tgz --username='\$oauthtoken' --password=$API_KEY --untar

    # Start cluster

    # AI ENGINE
    # Override resources to allow CPU only
    yq -i '.aiengine.resources = {}' morpheus-ai-engine/values.yaml
    helm upgrade --install --set ngc.apiKey="$API_KEY" --set resources="{}" --namespace $NAMESPACE ai-engine morpheus-ai-engine

    # SDK 
    # Remap SDK to custom image with jupyter
    yq -i '
        .sdk.registry = "registry.rc.nectar.org.au" |
        .sdk.image = "morpheus/morpheus-sdk-jupyterlab" |
        .sdk.version = "latest"
    ' morpheus-sdk-client/values.yaml

    # Add environment variables
    yq -i '
        .spec.containers.env[0].name = "password" |
        .spec.containers.env[0].value = "$PASSWORD"
    ' morpheus-sdk-client/templates/sdk-cli-pod.yaml

    # Add jupyter service
    cp /tmp/jupyter-service.yaml morpheus-sdk-client/templates/

    # Wait for default service account to spin up
    while microk8s kubectl get sa -n morpheus | grep -q 'No resources found'; do sleep 10; done
    CMD="jupyter lab --port 8888 --allow-root --no-browser --ServerApp.token='$PASSWORD' --ip='0.0.0.0'"
    helm upgrade --install --set ngc.apiKey="$API_KEY" --set sdk.args="$CMD" --namespace $NAMESPACE helper morpheus-sdk-client

    # MLFLOW
    helm upgrade --install --set ngc.apiKey="$API_KEY" --namespace $NAMESPACE mlflow morpheus-mlflow
EOF
