#!/bin/bash -x

# Retrieve Terraform outputs
REGISTRY_DNS=$(terraform output -raw default_registry_dns)
WORKLOAD_DNS=$(terraform output -raw workload_dns)
RANCHER_DNS=$(terraform output -raw rancher_dns)


# Copy certificates from the registry to the local machine
scp -i id_rsa ubuntu@$REGISTRY_DNS:/home/ubuntu/certs/domain.crt ./certs

# Copy certificates from the local machine to the workload and rancher instances
scp -i id_rsa ./certs/domain.crt ubuntu@$WORKLOAD_DNS:~/
scp -i id_rsa ./certs/domain.crt ubuntu@$RANCHER_DNS:~/
