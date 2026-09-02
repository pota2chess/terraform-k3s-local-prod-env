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

variable "gitea_instance_url" {
  type        = string
  description = "This is location gitea"
  default     = "http://gitea:3000"
}

variable "gitea_runner_registration_token" {
  type        = string
  description = "Token for gitea"
}
