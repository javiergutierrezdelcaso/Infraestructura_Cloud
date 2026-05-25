terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }

  # Terraform Cloud — conecta este repo vía VCS Provider
  # Sustituye "TU_ORGANIZACION" y "TU_WORKSPACE" por los tuyos de Terraform Cloud
  cloud {
    organization = "TU_ORGANIZACION"

    workspaces {
      name = "tfg-infraestructura"
    }
  }
}

provider "azurerm" {
  features {}

  # Las credenciales NO van aquí en texto plano.
  # Se configuran como variables de entorno en Terraform Cloud:
  #   ARM_CLIENT_ID
  #   ARM_CLIENT_SECRET
  #   ARM_SUBSCRIPTION_ID
  #   ARM_TENANT_ID
}
