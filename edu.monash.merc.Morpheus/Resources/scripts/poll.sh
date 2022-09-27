#!/bin/bash -xe

# Wait for morpheus to finish initialising
while [[ $(microk8s kubectl get pods -n morpheus | grep -c 'Running') -lt 5 ]]; do sleep 10; done
