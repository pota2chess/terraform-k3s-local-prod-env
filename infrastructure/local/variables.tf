variable "debug" {
  type        = string
  description = "The flag of debug for a container"
  default     = "0"
}

variable "localstack_auth_token" {
  description = "Token for LocalStack"
  type        = string # export TF_VAR_localstack_auth_token="token_here"
  sensitive   = true
}

variable "image_name" {
  type        = string
  description = "Name's image for my app"
  default     = "birthday"
}

variable "image_tag" {
  type        = string
  description = "Tag's image for image my app"
  default     = "default_value"
}

variable "local_registry" {
  type    = string
  default = "localhost:5000"
}
