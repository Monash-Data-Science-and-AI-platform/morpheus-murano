Murano NVIDIA Morpheus
===============

This is the source for an NVIDIA Morpheus Murano package running on the NeCTAR cloud.

A Makefile is included to help the build process.

You will need your NeCTAR cloud credentials loaded and the Murano CLI tools
available in your path.

This Murano App uses a microk8s cluster to provide a space to test NVIDIA's Morpheus on the Nectar cloud. To seperate Morpheus from any other deployments you may wish to test, all the `morpheus` namespace has been used. 

This app includes a jupyter lab server to make things more user friendly during experimentation and NginX to make accessing it and the MLFlow UI easier.

The morpheus stack includes:

- [MLFlow](https://mlflow.org/) to manage models
- [Triton](https://developer.nvidia.com/nvidia-triton-inference-server) as an inference server
- [Kafka](https://kafka.apache.org/) as a data broker

You can check the health of the cluster using:
`microk8s kubectl -n morpheus get all`

You can access the Jupyter Lab at `{address}/`

You can access the MLFlow UI at `{address}/mlflow`