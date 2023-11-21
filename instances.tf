
#-----------------------------------------------------------------------------------------------------------------
# AWS EC2 instance for creating a docker container private registry
resource "aws_instance" "default_registry" {
  # create the ec2 instance only after these resources are created.
  depends_on = [
    aws_route_table_association.rancher_route_table_association
  ]
  # Retrieve the proper AWS AMI (Amazon Machine Image)
  ami           = data.aws_ami.ubuntu.id
  # EC2 instance type and size
  instance_type = var.instance_type

  # create secure key pair, attach to created vpc and subnet and ensure the instance is accessible from the internet with a public IP
  key_name                    = aws_key_pair.nick_key_pair.key_name
  vpc_security_group_ids      = [aws_security_group.rancher_sg_allowall.id]
  subnet_id                   = aws_subnet.rancher_subnet.id#
  associate_public_ip_address = true

  # Instance HD size
  root_block_device {
    volume_size = 40
    tags = {
      "Name" = "${var.prefix}-volume-default-registry"
    }
  }

  provisioner "file" {
    source      = "${path.module}/scripts/manage_default_registry.sh"
    destination = "/home/ubuntu/manage_default_registry.sh"

    connection {
      type        = "ssh"
      host        = aws_instance.default_registry.public_ip
      user        = local.node_username
      private_key = tls_private_key.global_key.private_key_pem
    }
  }

  provisioner "file" {
    source      = "${path.module}/files/rancher-images.txt"
    destination = "/home/ubuntu/rancher-images.txt"

    connection {
      type        = "ssh"
      host        = self.public_ip
      user        = local.node_username
      private_key = tls_private_key.global_key.private_key_pem
    }
  }

  provisioner "file" {
    source      = "${path.module}/files/rancher-load-images.sh"
    destination = "/home/ubuntu/rancher-load-images.sh"

    connection {
      type        = "ssh"
      host        = self.public_ip
      user        = local.node_username
      private_key = tls_private_key.global_key.private_key_pem
    }
  }

  provisioner "file" {
    source      = "${path.module}/files/rancher-save-images.sh"
    destination = "/home/ubuntu/rancher-save-images.sh"

    connection {
      type        = "ssh"
      host        = self.public_ip
      user        = local.node_username
      private_key = tls_private_key.global_key.private_key_pem
    }
  }

  user_data = templatefile(
    "${path.module}/scripts/userdata_default_registry.template",
    {}
  )

  # execute command on the newly created instance.
  provisioner "remote-exec" {
    # the script has to wait for cloud-init to complete
    # cloud-init -> system for early initialization of cloud instances
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait > /dev/null",
      "echo 'Completed cloud-init!'",
    ]

    # Specify how terraform will connect to the instance.
    connection {
      type        = "ssh"
      host        = self.public_ip
      user        = local.node_username
      private_key = tls_private_key.global_key.private_key_pem
    }
  }

  tags = {
    Name    = "${var.prefix}-default-registry"
    Creator = var.creator
  }
}

resource "null_resource" "scp_file" {
  depends_on = [ aws_instance.default_registry ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/ec2_download_cert.sh ${aws_instance.default_registry.public_dns}"
  }
}
#-----------------------------------------------------------------------------------------------------------------
# AWS EC2 instance for creating a single node RKE cluster and installing the Rancher server
resource "aws_instance" "rancher_server" {
  # create the ec2 instance only after these resources are created.
  depends_on = [
    aws_route_table_association.rancher_route_table_association,
    aws_instance.default_registry
  ]
  # Retrieve the proper AWS AMI (Amazon Machine Image)
  ami           = data.aws_ami.ubuntu.id
  # EC2 instance type and size
  instance_type = var.instance_type

  # create secure key pair, attach to created vpc and subnet and ensure the instance is accessible from the internet with a public IP
  key_name                    = aws_key_pair.nick_key_pair.key_name
  vpc_security_group_ids      = [aws_security_group.rancher_sg_allowall.id]
  subnet_id                   = aws_subnet.rancher_subnet.id
  associate_public_ip_address = true

  # Instance HD size
  root_block_device {
    volume_size = 30
    tags = {
      "Name" = "${var.prefix}-volume-rancher-server"
    }
  }

  provisioner "file" {
    source      = "${path.module}/certs/domain.crt"
    destination = "/home/ubuntu/domain.crt"

    connection {
      type        = "ssh"
      host        = self.public_ip
      user        = local.node_username
      private_key = tls_private_key.global_key.private_key_pem
    }
  }

  # execute command on the newly created instance.
  provisioner "remote-exec" {
    # the script has to wait for cloud-init to complete
    # cloud-init -> system for early initialization of cloud instances
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait > /dev/null",
      "echo 'Completed cloud-init!'",
    ]

    # Specify how terraform will connect to the instance.
    connection {
      type        = "ssh"
      host        = self.public_ip
      user        = local.node_username
      private_key = tls_private_key.global_key.private_key_pem
    }
  }

  tags = {
    Name    = "${var.prefix}-rancher-server"
    Creator = var.creator
  }
}

#-----------------------------------------------------------------------------------------------------------------
# AWS EC2 instance for creating a single node workload cluster
resource "aws_instance" "workload_node" {
  depends_on = [
    aws_route_table_association.rancher_route_table_association,
    aws_instance.default_registry,
    rancher2_cluster_v2.workload_node
  ]

  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  key_name                    = aws_key_pair.nick_key_pair.key_name
  vpc_security_group_ids      = [aws_security_group.rancher_sg_allowall.id]
  subnet_id                   = aws_subnet.rancher_subnet.id
  associate_public_ip_address = true

  root_block_device {
    volume_size = 30
    tags = {
      "Name" = "${var.prefix}-volume-workload-node"
    }
  }

  provisioner "file" {
    source      = "${path.module}/certs/domain.crt"
    destination = "/home/ubuntu/domain.crt"

    connection {
      type        = "ssh"
      host        = self.public_ip
      user        = local.node_username
      private_key = tls_private_key.global_key.private_key_pem
    }
  }

  user_data = templatefile(
    "${path.module}/scripts/userdata_workload_node.template",
    {
      register_command = rancher2_cluster_v2.workload_node.cluster_registration_token.0.insecure_node_command
    }
  )

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait > /dev/null",
      "echo 'Completed cloud-init!'",
    ]

    connection {
      type        = "ssh"
      host        = self.public_ip
      user        = local.node_username
      private_key = tls_private_key.global_key.private_key_pem
    }
  }

  tags = {
    Name    = "${var.prefix}-workload-node"
    Creator = "${var.creator}"
  }
}
