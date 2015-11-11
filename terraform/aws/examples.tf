# Various examples that can be run against a cockroach cluster in AWS.
# A cockroach cluster should be created first by following the steps in README.md.
# To enable an example, change the number of instances on the command line. eg:
# terraform apply <flags for cockroach cluster> --var=example_block_writer_instances=1
# See the "provisioner file" stanza for the desired path to the built linux binary.

# Number of instances for the block writer example. Set to 1 to enable the example.
# The block writer example does not support multiple instances. Expect badness if
# set greater than 1.
variable "example_block_writer_instances" {
  default = 0
}
output "example_block_writers" {
  value = "${join(",", aws_instance.example_block_writer.*.public_dns)}"
}

resource "aws_instance" "example_block_writer" {
    tags {
      Name = "example-block-writer"
    }

    ami = "${var.aws_ami_id}"
    availability_zone = "${var.aws_availability_zone}"
    instance_type = "${var.aws_instance_type}"
    security_groups = ["${aws_security_group.default.name}"]
    key_name = "${var.key_name}"
    count = "${var.example_block_writer_instances}"

    connection {
      user = "ubuntu"
      key_file = "~/.ssh/${var.key_name}.pem"
    }

    provisioner "file" {
        source = "../../../examples-go/block_writer/block_writer"
        destination = "/home/ubuntu/block_writer"
    }

   provisioner "remote-exec" {
        inline = [
          "chmod 755 block_writer",
          "nohup ./block_writer --db-url=http://${aws_elb.elb.dns_name}:${var.cockroach_port} > example.STDOUT 2>&1 &",
          "sleep 5",
        ]
   }
}
