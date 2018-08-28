variable "name" {
  description = "Top-level name of configuration: lowercase, dash-separated"
}

variable "heroku_email" {}
variable "heroku_api_key" {}
variable "heroku_enterprise_team" {}

variable "aws_access_key" {}
variable "aws_secret_key" {}

variable "aws_region" {
  default = "us-east-1"
}

variable "instance_public_key" {}

variable "aws_to_heroku_common_region" {
  default = {
    "eu-west-1" = "eu"
    "us-east-1" = "us"
  }
}

variable "aws_to_heroku_private_region" {
  default = {
    "eu-west-1"      = "dublin"
    "eu-central-1"   = "frankfurt"
    "us-west-2"      = "oregon"
    "ap-southeast-2" = "sydney"
    "ap-northeast-1" = "tokyo"
    "us-east-1"      = "virginia"
  }
}

# Heroku app: "Health"
variable "health_app_slug_file_path" {
  description = "Heroku slug archive to release"
  default     = "health-app/heroku-slug.tgz"
}

variable "health_app_count" {
  description = "Heroku dyno quantity"
  default     = 1
}

variable "health_app_size" {
  description = "Heroku dyno size"
  default     = "Private-S"
}

# AWS ECS/Docker app: "Health Checker"
variable "health_checker_app_image" {
  description = "Docker image to run in the ECS cluster"
  default     = "mars/peer-health-checker:latest"
}

variable "health_checker_app_port" {
  description = "Port exposed by the docker image to redirect traffic to"
  default     = 80
}

variable "health_checker_app_count" {
  description = "Number of docker containers to run"
  default     = 1
}
