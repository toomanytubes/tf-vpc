variable "name" {
  description = "VPC name"
}

variable "environment" {
  description = "Environment name, e.g. \"prod, test, dev\""
}

variable "region" {
  description = "AWS region in which resources are created"
}

variable "cidr" {
  description = "CIDR block to provision for the VPC"
}


/**
 * VPC
 */

resource "aws_vpc" "main" {
  cidr_block = "${var.cidr}"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags {
    Name        = "${var.name}"
    Environment = "${var.environment}"
  }
}

variable "region_az_count" {
  # Mapping of region name to number of azs to use in that region
  type = "map"
  default = {
    us-east-1      = 3
    us-east-2      = 3
    us-west-1      = 2
    us-west-2      = 3
    eu-west-1      = 3
    eu-central-1   = 2
    ap-northeast-1 = 2
    ap-northeast-2 = 2
    ap-southeast-1 = 2
    ap-southeast-2 = 3
    ap-south-1     = 2
    sa-east-1      = 3
  }
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "private" {
  vpc_id            = "${aws_vpc.main.id}"
  cidr_block        = "${cidrsubnet(aws_vpc.main.cidr_block, 3, count.index * 2 + 0)}"
  availability_zone = "${element(data.aws_availability_zones.available.names, count.index)}"
  count             = "${lookup(var.region_az_count, var.region)}"

  tags {
    Name = "${var.name}-${format("private-%02d", count.index+1)}"
  }
}

resource "aws_subnet" "public" {
  vpc_id            = "${aws_vpc.main.id}"
  cidr_block        = "${cidrsubnet(aws_vpc.main.cidr_block, 4, count.index * 4 + 2)}"
  availability_zone = "${element(data.aws_availability_zones.available.names, count.index)}"
  count             = "${lookup(var.region_az_count, var.region)}"
  map_public_ip_on_launch = true

  tags {
    Name = "${var.name}-${format("public-%02d", count.index+1)}"
  }
}

resource "aws_subnet" "protected" {
  vpc_id            = "${aws_vpc.main.id}"
  cidr_block        = "${cidrsubnet(aws_vpc.main.cidr_block, 5, count.index * 8 + 6)}"
  availability_zone = "${element(data.aws_availability_zones.available.names, count.index)}"
  count             = "${lookup(var.region_az_count, var.region)}"

  tags {
    Name = "${var.name}-${format("protected-%02d", count.index+1)}"
  }
}

/**
 * Gateways
 */

resource "aws_internet_gateway" "main" {
  vpc_id = "${aws_vpc.main.id}"

  tags {
    Name        = "${var.name}"
    Environment = "${var.environment}"
  }
}


/**
 * Route tables
 */

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.main.id}"

  tags {
    Name = "${var.name}-public-01"
  }
}

resource "aws_route" "public" {
  route_table_id         = "${aws_route_table.public.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.main.id}"
}

resource "aws_route_table" "private" {
  vpc_id = "${aws_vpc.main.id}"

  tags {
    Name = "${var.name}-private-01"
  }
}


/**
 * Route associations
 */

resource "aws_route_table_association" "public" {
  count          = "${lookup(var.region_az_count, var.region)}"
  subnet_id      = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_route_table_association" "private" {
  count          = "${lookup(var.region_az_count, var.region)}"
  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${aws_route_table.private.id}"
}

resource "aws_route_table_association" "protected" {
  count          = "${lookup(var.region_az_count, var.region)}"
  subnet_id      = "${element(aws_subnet.protected.*.id, count.index)}"
  route_table_id = "${aws_route_table.private.id}"
}


/**
 * Outputs
 */

// The VPC ID
output "id" {
  value = "${aws_vpc.main.id}"
}

// The region in which the infra lives.
output "region" {
  value = "${var.region}"
}

// The environment of the stack, e.g "prod".
output "environment" {
  value = "${var.environment}"
}

output "cidr" {
  value = "${aws_vpc.main.cidr_block}"
}

// A list of public subnet IDs.
output "public_subnets" {
  value = ["${aws_subnet.public.*.id}"]
}

// A list of private subnet IDs.
output "private_subnets" {
  value = ["${aws_subnet.private.*.id}"]
}

// A list of protected subnet IDs.
output "protected_subnets" {
  value = ["${aws_subnet.protected.*.id}"]
}

// The list of availability zones of the VPC.
output "availability_zones" {
  value = ["${aws_subnet.public.*.availability_zone}"]
}

// The internal route table ID.
output "internal_rtb_id" {
  value = "${join(",", aws_route_table.private.*.id)}"
}

// The external route table ID.
output "external_rtb_id" {
  value = "${aws_route_table.public.id}"
}
