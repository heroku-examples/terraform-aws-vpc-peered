provider "aws" {
  version    = "~> 1.10"
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.aws_region}"
}

provider "heroku" {
  email   = "${var.heroku_email}"
  api_key = "${var.heroku_api_key}"
}

provider "local" {
  version = "~> 1.1"
}

module "heroku_aws_vpc" {
  source     = "git::https://github.com/mars/terraform-aws-vpc.git?ref=v1.0.0"
  name       = "${var.name}"
  aws_region = "${var.aws_region}"

  providers = {
    aws   = "aws"
    local = "local"
  }
}

resource "heroku_space" "default" {
  name         = "${var.name}"
  organization = "${var.heroku_enterprise_team}"
  region       = "${lookup(var.aws_to_heroku_private_region, var.aws_region)}"
}

resource "heroku_space_inbound_ruleset" "default" {
  space = "${heroku_space.default.name}"

  rule {
    action = "allow"
    source = "0.0.0.0/0"
  }
}

data "heroku_space_peering_info" "default" {
  name = "${heroku_space.default.name}"
}

resource "aws_vpc_peering_connection" "request" {
  peer_owner_id = "${data.heroku_space_peering_info.default.aws_account_id}"
  peer_vpc_id   = "${data.heroku_space_peering_info.default.vpc_id}"
  vpc_id        = "${module.heroku_aws_vpc.id}"
}

resource "heroku_space_peering_connection_accepter" "accept" {
  space                     = "${heroku_space.default.name}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.request.id}"
}

resource "aws_route" "peered_private_space" {
  route_table_id            = "${module.heroku_aws_vpc.public_route_table_id}"
  destination_cidr_block    = "${data.heroku_space_peering_info.default.vpc_cidr}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.request.id}"
  depends_on                = ["aws_vpc_peering_connection.request"]
}
