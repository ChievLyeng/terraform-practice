variable "environment" {
  description = "Label used inside the generated config file"
  type        = string
  default     = "practice"
}

variable "app_port" {
  description = "Fake port number written into the generated config"
  type        = number
  default     = 8080

  validation {
    condition     = var.app_port > 0 && var.app_port < 65536
    error_message = "app_port must be a valid TCP port (1-65535)."
  }
}
