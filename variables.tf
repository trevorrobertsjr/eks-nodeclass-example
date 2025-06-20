variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# Variable to control test deployment creation
variable "create_test_deployment" {
  description = "Whether to create a test deployment to verify the NodePool"
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Terraform   = "true"
    Environment = "dev"
    Project     = "eks-auto-mode"
  }
}

variable "additional_tags" {
  description = "Additional tags to apply to specific resources"
  type        = map(string)
  default     = {}
}