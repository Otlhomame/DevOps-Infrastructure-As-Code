#Make the terraform script more dynamic by adding variables
#Initialise the var.host_os variable on the main.tf file
variable "host_os" {
  type = string
  default = "windows"
}