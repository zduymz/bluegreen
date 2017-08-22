# This configuration is to create EC2 instance, to perform basic configuration.
# Intended to use in build image process. Making ami

# Unique id for the build
variable "build_id" {
  type = "string"
  #default ="xxx"
}

# Define build environment
provider "aws" {
  
  alias = "build"

  # Region still required
  region = "us-east-1"

  # this one has to be set up with credentials and profile
  shared_credentials_file = "/var/lib/jenkins/.aws/credentials"
  profile = "staging"

}

# Define build image access key
resource "aws_key_pair" "builder" {
  # Use our provider for the build
  provider = "aws.build"
  key_name   = "builder-key-${var.build_id}"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCR4/lZMFn4p1Q3VqUX6Aht0096EVwOhLonVmKqbiqlxG7mTCloItkYK8uZgWvcxJYRh3PhFd5sVYWELgwUUVDkJ5mjoX+g2P4sDqfkfqbAeHdGjp04KWZFvQNcKHE4NqYKwkHzc+nC5mYZD4AAfKBQ5Azv+sHC7qfHT3DEU0PDm7V8PulDcaLUreHn+qrS7dz8vk/hLYD+PGlsNNWRa+hA5ejxrS+aZbdEtDIbxGIP32D8Ih+yqRa2rbeAi0EfzbnT5ctGzPr79Qdw1BHcI/c0J/rq1LQRuWr4Y8yclmlFoWsq306AhN4eriVXGEtKTz43AsqgR0EVI503D01sHPSX jenkins@ip-172-31-16-30.ec2.internal"
}

resource "aws_security_group" "aws_sec" {
  name        = "allow_build_image_${var.build_id}"
  description = "Allow build image"
  provider = "aws.build"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # use tags to identify environment, futher cleanup
  tags {
    Name = "Allow build image"
    env = "build"
    class = "imagesrc"
    build = "${var.build_id}"
  }
}

# Define base image parameters.
data "aws_ami" "optapp" {

  # Use our provider for the build
  provider = "aws.build"

  # One can filter by regex
  # name_regex = "^amzn-ami.+\\d+.+gp2$"

  # In case there is multiple images, use recent on.
  most_recent = true

  # Filter ami images by name
  filter {
    name   = "name"
    values = [ 
      "amzn-ami-hvm-2017.03.1.20170623-x86_64-gp2", 
      "amzn-ami-hvm-2017.03.*-x86_64-gp2" 
    ]
  }

  # Filter by VT
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  # One can filter by owner id
  # owners = ["099720109477"]
}

# Describe resource
resource "aws_instance" "optapp" {

  # Use defined build environment
  provider = "aws.build"

  # User defined build image
  ami           = "${data.aws_ami.optapp.id}"
  instance_type = "t2.micro"
  count = 1

  # Use builder ssh key
  key_name = "builder-key-${var.build_id}"

  security_groups = [
   "${aws_security_group.aws_sec.name}"
  ]


  # Define tags as needed.
  # Name: uniq across builds
  # end: filter build environment
  # class: mark instances as "image preparation instances"
  tags {
    Name = "BLD: ${var.build_id}"
    env = "build"
    class = "imagesrc"
    build = "${var.build_id}"  
  }

  # Save data locally for futher reference
  #provisioner "local-exec" {
  #  command = "echo ${resource} > resource.txt"
  #}

  # Copy deploy script\whatever to use on the host
  provisioner "file" {
    source      = "test.sh"
    destination = "~/test.sh"

    connection {
      type = "ssh"
      user = "ec2-user"
      # password = ""
      private_key = "${file("/var/lib/jenkins/.ssh/jenkins_key")}"
      # agent = true
    }
  }

  # Execute commands, use copied files.
  provisioner "remote-exec" {
    connection {
      type = "ssh"
      user = "ec2-user"
      # password = ""
      private_key = "${file("/var/lib/jenkins/.ssh/jenkins_key")}"
      # agent = true
    }
    inline = [
     "ls -la",
     "sudo ls -la",
     "sudo yum check-update",
     "echo ${aws_instance.optapp.private_ip}",
     "chmod u+x,g+x,o+x ~/test.sh",
     "sudo /home/ec2-user/test.sh"
    ]
  }

  # Copy and execute script as is
  provisioner "remote-exec" {
    connection {
      type = "ssh"
      user = "ec2-user"
      # password = ""
      private_key = "${file("/var/lib/jenkins/.ssh/jenkins_key")}"
      # agent = true
    }
    script = "test.sh"
  }
}

output "optapp_ip" {
  value = "${aws_instance.optapp.public_ip}"
}

output "optapp_id" {
  value = "${aws_instance.optapp.id}"
}

output "build_id" {
  value = "${var.build_id}"
 }
