#Creating an AWS VPC using Terraform script

resource "aws_vpc" "mtc_vpc" {
  cidr_block           = "10.123.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dev"
  }
}

#Provisioning a subnet for every time we log into our created VPC

resource "aws_subnet" "mtc_public_subnet" {
  vpc_id                  = aws_vpc.mtc_vpc.id #Not a string but a reference to our vpc resource unique id which you can see by terraform state show cmd
  cidr_block              = "10.123.1.0/24"    #One of the subnets within the /16 cidr block above
  map_public_ip_on_launch = true               #Remember that according to terraform docs, it is set to false by default
  availability_zone       = "eu-west-2a"       #Provide an availability zone for the vpc to map to the subnet ip address

  tags = {
    Name = "dev-public" #Name it public to make sure you dont place sensetive resources on a public subnet
  }
}

#Create an internet gateway for your cloud resources to communicate with the internet
resource "aws_internet_gateway" "mtc_internet_gateway" {
  vpc_id = aws_vpc.mtc_vpc.id

  tags = {
    Name = "dev-igw"
  }
}

#Dreating Route table to route traffic between the subnet attached to vpc and internet gateway
resource "aws_route_table" "mtc_public_rt" {
  vpc_id = aws_vpc.mtc_vpc.id

  tags = {
    Name = "dev_public_rt"
  }
}

#Creating the AWS route to properly map to the relevant route table we created above
resource "aws_route" "default_route" { #Default meaning for all traffic to reach the internet
  route_table_id         = aws_route_table.mtc_public_rt.id
  destination_cidr_block = "0.0.0.0/0" #Means all IP Adresses of the subnet will go through this internet gateway 
  gateway_id             = aws_internet_gateway.mtc_internet_gateway.id
}

#Creating a connection between our route table and subnet via a route table association
resource "aws_route_table_association" "mtc_public_assoc" {
  subnet_id      = aws_subnet.mtc_public_subnet.id
  route_table_id = aws_route_table.mtc_public_rt.id
}

#Creating a security group to make sure no one else can connect to our private resources which our infrastructure relies on
resource "aws_security_group" "mtc_sg" {
  name        = "dev_sg" #You dont need to create a tag as a security group has a name attricbute which helps it inherently categorise resources
  description = "dev security group"
  vpc_id      = aws_vpc.mtc_vpc.id

  #Defining which computers have the right to get into our network boundary layer
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"                  #To recognise any of the different protocols like UDP, TCP etc
    cidr_blocks = ["Your IP Address"] #Make sure you use your own ip address here to make sure that only your computer is cleared to connect to the AWS resources by the security group when you test your kungfu        
  }

  #Defining the permission for our internal resources to acccess the internet through our network boundary layer
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] #Making sure your internal subnet can access anything on the internet
  }
}

#Creating a KeyPair and a terraform authentication resource that utilizes that KeyPair. We'll use this resource to SSH into the EC2 instance we'll create later
#Once the KeyPair has been created on terminal, use Terraform file function to assign our keypair to the terraform resource we'll use to ssh into the EC2 later

resource "aws_key_pair" "mtc_auth" {
  key_name = "mtckey"
  public_key = file("~/.ssh/mtckey.pub") # File function allows us to point to the public key directory instead of typing out the whole keypair
}

#Now position the empty fresh EC2 instance for deployment. Putting it in place before installing anything in it yet

resource "aws_instance" "dev_node" {
  instance_type = "t2.micro" #Free EC2 instance by AWS
  ami = data.aws_ami.server_ami.id

  #Defining multiple layers of security needed to protect the EC2 instance. Order of least privileges
  key_name = aws_key_pair.mtc_auth.id
  vpc_security_group_ids = [aws_security_group.mtc_sg.id]
  subnet_id = aws_subnet.mtc_public_subnet.id
  
  #Use Userdata to bootstrap the instance and install Docker engine. This makes sure we deploy the EC2 instance with Docker ready to be used for futher dev needs
  #Adding userdata to our resource from userdata.tpl file allows us to run docker commands as an ubuntu user as the TPL file script installs updated docker and adds ubuntu to the docker group
  user_data = file("userdata.tpl") #File function extracts userdata from tpl file and allows to bootstrap our instance

  #Allow the re-sizing of default size of drive on this instance
  root_block_device {
    volume_size = 10
  }

  tags = {
    Name = "dev-node"
  }  

  #Use provisioner toe configure the vscode in our terminal to be able to ssh into our EC2 instance
  
  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-config.tpl", { #Pay attention to the variable (var.host_os) which makes reference to the variables.tf file. We may choose to change anytime in future and so not have to worry about chaning line by line when changing components of infrastructure
      hostname = self.public_ip,
      user = "ubuntu",
      identityfile = "~/.ssh/mtckey"
    })
    #Interpreter tells our provisioner what it needs to run the script
    interpreter = var.host_os == "windows" ? ["Powershell" , "-Command"] : ["bash" , "-c"] #Use conditional expressions to choose the interpreter we need dynamically, based on the host OS variable
  }  
}