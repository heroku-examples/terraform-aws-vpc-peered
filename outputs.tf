output "health_checker_private_dns_name" {
  value = "${aws_instance.health_checker.private_dns}"
}
