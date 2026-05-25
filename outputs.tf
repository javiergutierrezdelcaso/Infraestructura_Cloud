output "vm_public_ip" {
  description = "IP pública de la VM — úsala en el inventario de Ansible y en GitHub Actions"
  value       = azurerm_public_ip.vm.ip_address
}

output "resource_group_name" {
  description = "Nombre del Resource Group creado"
  value       = azurerm_resource_group.main.name
}

output "vm_name" {
  description = "Nombre de la máquina virtual"
  value       = azurerm_linux_virtual_machine.main.name
}

output "key_vault_uri" {
  description = "URI del Key Vault para referenciar secretos desde GitHub Actions"
  value       = azurerm_key_vault.main.vault_uri
}
