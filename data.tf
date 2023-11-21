# Data for AWS module
data "aws_ami" "ubuntu" {
  most_recent = true
  # Canonical, the company behind Ubuntu, provides official Ubuntu AMIs.
  # You can use their AWS account ID to filter for official images.
  owners      = ["099720109477"] # Canonical

  # Filter the AMI by name to match the desired Ubuntu pattern.
  # The example below assumes you want Ubuntu 20.04 LTS, adjust as needed.
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  # Filter by virtualization type. 'hvm' stands for Hardware Virtual Machine.
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  # Ensure the AMI is for the x86_64 architecture.
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  # Ensure the AMI uses EBS as its root device type.
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}


# In Terraform, the `filter` block within a `data` source.
# Is used to refine the search for a specific object within a provider's set of resources.
# Each `filter` block specifies a name and a list of values
# The resource must match all provided filters to be selected.
# In this case the `data` block is querying the provider (AWS) for resources (AWS AMI) that match all the given criterias.
# Once terraform finds the data, it can be accessed as an attribute