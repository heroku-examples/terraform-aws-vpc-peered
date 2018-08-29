provider "template" {
  version = "~> 1.0"
}

resource "heroku_app" "health" {
  name  = "${var.name}-health"
  space = "${heroku_space.default.name}"

  organization = {
    name = "${var.heroku_enterprise_team}"
  }

  region           = "${lookup(var.aws_to_heroku_private_region, var.aws_region)}"
  internal_routing = true
}

resource "heroku_slug" "health" {
  app                            = "${heroku_app.health.id}"
  buildpack_provided_description = "Node.js"
  commit_description             = "manual slug build v4"
  file_path                      = "${var.health_app_slug_file_path}"

  process_types = {
    web = "npm start"
  }
}

resource "heroku_app_release" "health" {
  app     = "${heroku_app.health.id}"
  slug_id = "${heroku_slug.health.id}"
}

resource "heroku_formation" "health" {
  app        = "${heroku_app.health.id}"
  type       = "web"
  quantity   = "${var.health_app_count}"
  size       = "${var.health_app_size}"
  depends_on = ["heroku_app_release.health"]
}

resource "aws_iam_role" "ecs_instance_role" {
  name = "${var.name}-ecsInstanceRole"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs_ec2_instance" {
  role       = "${aws_iam_role.ecs_instance_role.id}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_ec2_instance" {
  name = "${var.name}-ecs-ec2-instance"
  role = "${aws_iam_role.ecs_instance_role.name}"
}

resource "aws_key_pair" "health_checker" {
  key_name   = "${var.name}-key"
  public_key = "${var.instance_public_key}"
}

data "aws_ami" "ecs_optimized" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn-ami-2018.03.e-amazon-ecs-optimized"]
  }
}

resource "aws_instance" "health_checker" {
  ami                         = "${data.aws_ami.ecs_optimized.id}"
  instance_type               = "t2.micro"
  subnet_id                   = "${module.heroku_aws_vpc.public_subnet_id}"
  associate_public_ip_address = true
  key_name                    = "${aws_key_pair.health_checker.key_name}"
  iam_instance_profile        = "${aws_iam_instance_profile.ecs_ec2_instance.name}"

  vpc_security_group_ids = [
    # "${aws_security_group.allow_ssh.id}",
    "${aws_security_group.health_checker_container.id}",
  ]

  user_data = <<EOF
#!/bin/bash
echo ECS_CLUSTER=${aws_ecs_cluster.health_checker.name} >> /etc/ecs/ecs.config
EOF

  tags {
    Name = "health-checker-container"
  }
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow inbound ssh traffic"
  vpc_id      = "${module.heroku_aws_vpc.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "health_checker_container" {
  name        = "${var.name}-health-checker-container"
  description = "controls access to the Health Checker web app container"
  vpc_id      = "${module.heroku_aws_vpc.id}"

  ingress {
    from_port   = "${var.health_checker_app_port}"
    to_port     = "${var.health_checker_app_port}"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_cluster" "health_checker" {
  name = "${var.name}-health-checker-cluster"
}

data "template_file" "health_checker_container" {
  template = "${file("health-checker-app/ecs-app.json.tpl")}"

  vars {
    app_image  = "${var.health_checker_app_image}"
    aws_region = "${var.aws_region}"
    app_port   = "${var.health_checker_app_port}"
    logs_group = "${aws_cloudwatch_log_group.health_checker.name}"
    peer_url   = "http://${var.name}-health.herokuapp.com"
    self_url   = "http://${aws_instance.health_checker.private_dns}"
  }
}

resource "aws_ecs_task_definition" "health_checker" {
  family                = "${var.name}-health-checker-app-task"
  container_definitions = "${data.template_file.health_checker_container.rendered}"
}

resource "aws_ecs_service" "health_checker" {
  name            = "${var.name}-health-checker-service"
  cluster         = "${aws_ecs_cluster.health_checker.id}"
  task_definition = "${aws_ecs_task_definition.health_checker.arn}"
  desired_count   = "${var.health_checker_app_count}"
}

resource "aws_cloudwatch_log_group" "health_checker" {
  name = "/ecs/${var.name}"
}
