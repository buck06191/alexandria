variable "lambda_writer_bin_path" {
  description = "The binary path for the lambda that writes to dynamoDB."
  type        = string
  default     = "./lambda-bin/bootstrap"
}
