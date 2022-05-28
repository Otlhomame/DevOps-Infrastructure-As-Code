#Creating the AMI which we'll use to deploy the EC2 instance. Use a data source which is an AWS API query to receive information needed to deploy a resource from AWS

#Getting an AMI ID based on filters provided by us
data "aws_ami" "server_ami" {
  most_recent = true
  owners = ["099720109477"] #Owner can be found by searching for an AMI in public mode from EC2 section on AWS

  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }
}

