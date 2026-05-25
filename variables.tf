variable "location" {
  description = "Región de Azure donde se crearán los recursos"
  type        = string
  default     = "West Europe"
}

variable "environment" {
  description = "Entorno de despliegue: pre o pro"
  type        = string
  validation {
    condition     = contains(["pre", "pro"], var.environment)
    error_message = "El entorno debe ser 'pre' o 'pro'."
  }
}

variable "project_name" {
  description = "Nombre del proyecto, usado como prefijo en los recursos"
  type        = string
  default     = "tfg"
}

variable "vm_size" {
  description = "Tamaño de la máquina virtual"
  type        = string
  default     = "Standard_B1s" # La más barata, suficiente para el TFG
}

variable "admin_username" {
  description = "Usuario administrador de la VM"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "Clave pública SSH para acceder a la VM (contenido del archivo .pub)"
  type        = string
  sensitive   = true
}

variable "allowed_ssh_ip" {
  description = "IP desde la que se permite acceso SSH (tu IP pública). Usa '0.0.0.0/0' solo para pruebas."
  type        = string
}

variable "key_vault_name" {
  description = "Nombre único global del Azure Key Vault"
  type        = string
}
