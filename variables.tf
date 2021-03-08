variable "region" {
  type        = string
  description = "primary aws region where the services are created"
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment to host your resources."
  type        = string
  default     = ""
}

variable "module_name" {
  description = "Name of the module/project this site represents. e.g: test"
  type        = string
  default     = ""
}

variable "cert_domain" {
  description = "Name of the existing certificate domain "
  type        = string
  default     = ""
}

variable "hosted_zone" {
  description = "A public hosted zone name for e.g integrations.rd.elliemae.io"
  type        = string
  default     = "tonara.com"
}

variable "high_availability" {
  description = "Create fail-over s3 bucket with replication and associate with cloudfront"
  type        = bool
  default     = false
}

variable "allowed_domains" {
  description = "Add cors rule to add into s3 policy."
  type        = list(string)
}

variable "lambdas" {
  description = "Lambda function needs to be associated with cloudfront"
  default     = []
  type = list(object({
    type        = string
    arn         = string
    includeBody = bool
  }))
}
