#!/bin/bash -x
set -e
scp -o StrictHostKeyChecking=no -i ./certs/id_rsa ubuntu@${1}:/home/ubuntu/certs/domain.crt ./certs/domain.crt