variable "availability_zones" {
  type = list(any)
  default = [
  "ap-south-1a", "ap-south-1b", "ap-south-1c"]
  description = "Availability zones that the subnets should be distributed across"
}

variable "subnet_cidr_blocks" {
  type = map(any)
  default = {
    ec2 = [
    "10.0.10.0/24", "10.0.11.0/24"]
    elb = [
    "10.0.20.0/24", "10.0.21.0/24"]
  }
  description = "CIDR block for the subnet"
}