# Run the sql logic test suite on AWS.
# Prerequisites:
# - AWS account credentials and key as specified in cockroach-prod/terraform/aws/README.md
# - linux binary: cockroach/sql/sql.test
# - sqllogic test repo cloned
#
# Run with:
# terraform apply --var=aws_access_key="${AWS_ACCESS_KEY}" \
#                 --var=aws_secret_key="${AWS_SECRET_KEY}" \
#                 --var=sql_logic_instances=1
# Tear down AWS resources using:
# terraform destroy --var=aws_access_key="${AWS_ACCESS_KEY}" \
#                   --var=aws_secret_key="${AWS_SECRET_KEY}" \
#                   --var=sql_logic_instances=1
#
# The used logic tests are tarred and gzipped before launching the instance.
#
# Monitor the output of the tests by running:
# $ ssh -i ~/.ssh/cockroach.pem ubuntu@<instance> tail -F test.STDOUT

provider "aws" {
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
    region = "${var.aws_region}"
}

output "instance" {
  value = "${join(",", aws_instance.sql_logic_test.*.public_dns)}"
}

resource "aws_instance" "sql_logic_test" {
    tags {
      Name = "cockroach-sql-logic-test"
    }
    depends_on = ["null_resource.sql_tarball"]

    ami = "${var.aws_ami_id}"
    availability_zone = "${var.aws_availability_zone}"
    instance_type = "t1.micro"
    security_groups = ["${aws_security_group.default.name}"]
    key_name = "${var.key_name}"
    count = "${var.sql_logic_instances}"

    connection {
      user = "ubuntu"
      key_file = "~/.ssh/${var.key_name}.pem"
    }

    provisioner "file" {
        source = "${var.cockroach_repo}/sql/sql.test"
        destination = "/home/ubuntu/sql.test"
    }

    provisioner "file" {
        source = "sqltests.tgz"
        destination = "/home/ubuntu/sqltests.tgz"
    }

   provisioner "remote-exec" {
        inline = [
          "chmod 755 sql.test",
          "tar xfz sqltests.tgz",
          "nohup ./sql.test --test.run=TestLogic -d \"test/index/*/*/*.test\" 1>test.STDOUT 2>&1 &",
          "sleep 5",
        ]
   }
}

resource "null_resource" "sql_tarball" {
    provisioner "local-exec" {
        command = "tar cfz sqltests.tgz -C ${var.sqllogictest_repo} test/index/between test/index/commute test/index/delete test/index/in test/index/orderby test/index/orderby_nosort"
    }
}

resource "aws_security_group" "default" {
  name = "sqltest_security_group"

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
