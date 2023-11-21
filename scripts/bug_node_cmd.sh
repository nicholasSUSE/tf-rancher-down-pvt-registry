#!/bin/bash -x

echo "Starting bud_node_cmd script"
echo "Getting AWS information with curl..."
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
publicIP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/public-ipv4)
privateIP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/local-ipv4)


if [ -x "$(command -v docker)" ]; then
    echo "Docker is installed."
    echo "Cleaning any docker previous containers"
    if [ "$(docker ps -aq)" ]; then
        docker stop $(docker ps -aq) && docker rm $(docker ps -aq)
    else
        echo "No Docker containers to stop and remove."
    fi
else
    echo "Docker is not installed."

    echo "Downloading and installing docker through rancher script"
    curl -sfL https://releases.rancher.com/install-docker/20.10.sh | sh -

    echo "Give ubuntu user root permissions"
    sudo usermod -aG docker ubuntu

    # Set the sysctl configuration for net.bridge.bridge-nf-call-iptables
    echo "Setting net.bridge.bridge-nf-call-iptables=1 in sysctl..."
    echo 'net.bridge.bridge-nf-call-iptables=1' | sudo tee -a /etc/sysctl.conf

    # Reload sysctl to apply changes
    echo "Reloading sysctl to apply changes..."
    sudo sysctl -p

    # Verify and display the setting
    echo "Verifying the applied setting..."
    sysctl net.bridge.bridge-nf-call-iptables

    # Open TCP/6443 for all
    echo "opening TCP/6443 for all"
    sudo iptables -A INPUT -p tcp --dport 6443 -j ACCEPT
    echo "checking if it worked, you should see something like:(141 17725 ACCEPT     tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:6443
    ) in the next line"
    sudo iptables -L -n -v | grep 6443

    echo "Allowing TCP Forwarding for SSH"
    echo 'AllowTcpForwarding yes' | sudo tee -a /etc/ssh/sshd_config
    echo "Restarting SSHD service"
    sudo systemctl restart sshd
    echo "checking if worked, next line should contain:(allowtcpforwarding yes)"
    sudo sshd -T | grep allowtcpforwarding

    echo "Creating ca-certificates workaround infrastructure"
    sudo mkdir -p /etc/docker/certs.d/${2}
    sudo cp /home/ubuntu/domain.crt /etc/docker/certs.d/${2}/ca.crt
    sudo cp domain.crt /usr/local/share/ca-certificates/domain.crt

    echo "Updating Linux Ca Certificates"
    sudo update-ca-certificates

    echo "Restarting docker service"
    sudo systemctl restart docker
fi


newgrp docker <<EOF
echo "Executing Import Cluster Node Command for RKE"
${1} --address $publicIP --internal-address $privateIP --controlplane --etcd --worker
EOF

echo "Done!"
echo "Public IP"
echo $publicIP
echo "Private IP"
echo $privateIP
