#
# Variables Configuration
#

variable "aws_region" {
  description = "The AWS region to deploy resources in."
  default     = "eu-west-2"
}

variable "aws_profile" {
  type        = string
  description = "AWS user profile creds"
  default     = "<your_aws_profile_name>"
}

variable "control_plane_public_access_cidrs" {
  type = list(any)
  default = [
    "<your_host_public_IP>",
  ]
}

variable "cluster-name" {
  description = "EKS cluster name."
  default     = "dev-demo"
  type        = string
}

variable "k8s_version" {
  description = "Kubernetes version."
  default     = "1.21"
  type        = string
}


# Assumption; vpc is n.n.h.h/16; eg first 2 octets.
# Subnets for vpc's use tf counts and will increment the 3rd octet and set the subnet to /24 (eg n.n.0.h/24)
# See also vpc_subnets

variable "vpc-network" {
  description = "vpc cidr network portion; eg 10.0 for 10.0.0.0/16."
  default     = "10.3"
  type        = string
}

variable "vpc-subnets" {
  description = "VPC number of subnets/AZs."
  default     = "3"
  type        = string
}

variable "inst-type" {
  description = "EKS worker instance type."
  default     = "t3.medium"
  type        = string
}

# I bumped this up as 20Gb is way to small for all those docker images that will be pulled.
variable "inst_disk_size" {
  description = "EKS worker instance disk size in Gb."
  default     = "50"
  type        = string
}

variable "inst_key_pair" {
  description = "EKS worker instance ssh key pair."
  default     = "spicysom-aws4-kp"
  type        = string
}

variable "num-workers" {
  description = "Number of eks worker instances to deploy."
  default     = "2"
  type        = string
}

variable "max-workers" {
  description = "Max number of eks worker instances that can be scaled."
  default     = "10"
  type        = string
}

variable "cw_logs" {
  type        = bool
  default     = false
  description = "Setup full Cloudwatch logging."
}

variable "ca" {
  type        = bool
  default     = false
  description = "Install k8s Cluster Autoscaler."
}
