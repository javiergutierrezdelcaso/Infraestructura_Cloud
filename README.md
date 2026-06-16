# 🏗️ EcoAnalyzer — Infraestructura Cloud

Repositorio de Infraestructura como Código (IaC) del proyecto **EcoAnalyzer**, 
desarrollado como Trabajo de Fin de Grado en Ingeniería Informática.

Gestiona el aprovisionamiento automatizado de recursos en **Microsoft Azure** 
mediante **Terraform** y la configuración de servidores mediante **Ansible**, 
integrados en pipelines CI/CD que se disparan automáticamente con cada cambio 
en el repositorio. Incluye gestión segura de secretos mediante **Azure Key Vault** 
y gobernanza de infraestructura mediante **políticas Sentinel**.


---

## Arquitectura

```
GitHub (push/PR)
│
├── Terraform Cloud        ────────────────────► Azure
│   ├── PR → Plan especulativo (CI)              ├── Resource Group
│   ├── PR → Política Sentinel (advisory)        ├── Red Virtual + Subred
│   └── Merge → Apply (CD)                       ├── IP Pública Estática
│                                                ├── Network Security Group
└── GitHub Actions                               ├── Máquina Virtual Ubuntu 22.04
└── Merge → Ansible                              ├── Azure Key Vault
└── Configura la VM                              └── Secreto eco-api-secret
```
---

## Entornos

| Entorno | Rama | Workspace Terraform Cloud | Resource Group |
|---|---|---|---|
| **PRE** (Preproducción) | `develop` | `TFG-Infraestructura-Azure-Terraform-PRE` | `rg-tfg-pre` |
| **PRO** (Producción) | `main` | `TFG-Infraestructura-Azure-Terraform-PRO` | `rg-tfg-pro` |

---

## Estructura del repositorio
```
TFG-Infraestructura-Azure-Terraform/
├── README.md 		                              # Manual de instrucciones y guía de uso del proyecto.
├── providers.tf                                  # Proveedor azurerm + conexión Terraform Cloud
├── variables.tf                                  # Declaración de variables con validaciones
├── main.tf                                       # Recursos de Azure (VM, red, NSG, Key Vault, secreto)
├── outputs.tf                                    # Outputs: IP pública, nombre de recursos, URI Key Vault
├── .gitignore                                    # Excluye .tfvars, .tfstate, .terraform/
├── terraform.tfvars.example                      # Ejemplo de variables (no subir valores reales)
├── sentinel/
│   ├── sentinel.hcl                              # Configuración del policy set
│   └── restrict-ssh-open.sentinel                # Política: detecta SSH abierto a Internet
└── ansible/
    ├── playbook.yml                              # Playbook principal
    ├── inventory.ini                             # Inventario local (desarrollo)
    └── roles/
        └── microservicio/
                    └── tasks/
                        └── main.yml              # Instala Python, FastAPI, Nginx, configura systemd
```

---

## Recursos aprovisionados por Terraform

| Recurso | Nombre PRE | Nombre PRO |
|---|---|---|
| Resource Group | `rg-tfg-pre` | `rg-tfg-pro` |
| Red Virtual | `vnet-tfg-pre` | `vnet-tfg-pro` |
| Subred | `snet-tfg-pre` | `snet-tfg-pro` |
| IP Pública Estática | `pip-tfg-pre` | `pip-tfg-pro` |
| Network Security Group | `nsg-tfg-pre` | `nsg-tfg-pro` |
| Interfaz de Red | `nic-tfg-pre` | `nic-tfg-pro` |
| Máquina Virtual Ubuntu 22.04 | `vm-tfg-pre` | `vm-tfg-pro` |
| Azure Key Vault | `kv-tfg-pre` | `kv-tfg-pro` |
| Secreto Key Vault | `eco-api-secret` | `eco-api-secret` |

El NSG permite tráfico entrante únicamente en el **puerto 22** (SSH) y 
**puerto 80** (Nginx). Uvicorn escucha exclusivamente en `127.0.0.1:8000` 
y no es accesible desde el exterior, quedando protegido detrás de Nginx 
como única entrada pública.

---

## Azure Key Vault

Cada entorno dispone de un Key Vault independiente provisionado por Terraform 
con `soft_delete_retention_days = 7` y `purge_protection_enabled = false`, 
lo que permite destruir y recrear la infraestructura de forma idempotente 
sin que los secretos en estado soft-delete bloqueen el siguiente apply.

El secreto `eco-api-secret` se crea automáticamente con el valor 
`eco-secret-<entorno>` y su URI se expone como output de Terraform:

```hcl
output "key_vault_uri" {
  description = "URI del Azure Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}
```

El workflow de Ansible lee este output desde la API de Terraform Cloud 
e inyecta la URI en el servicio systemd del microservicio como variable 
de entorno `KEY_VAULT_URI`, sin ningún valor hardcodeado.

### Cadena de inyección del secreto
```
Terraform (output key_vault_uri)

→ API Terraform Cloud

→ Workflow Ansible (GitHub Actions)

→ Servicio systemd (Environment=KEY_VAULT_URI=...)

→ main.py (os.getenv("KEY_VAULT_URI"))

→ Azure Key Vault SDK

```
### Idempotencia del Key Vault

Si se destruyen los recursos manualmente desde el portal de Azure sin 
ejecutar `terraform destroy`, el secreto puede quedar en estado 
soft-delete bloqueando el siguiente apply. Para resolverlo:

1. Ir al portal de Azure → Key Vault → **Deleted secrets**
2. Seleccionar `eco-api-secret` → **Purge**
3. Ejecutar el apply de Terraform normalmente

Con `purge_protection_enabled = false` y el permiso `Purge` en la 
access policy, Terraform puede gestionar este ciclo automáticamente 
en destrucciones controladas mediante `terraform destroy`.

---

## Gobernanza — Política Sentinel

Se ha implementado la política `restrict-ssh-open` en el directorio 
`sentinel/` conectada a ambos workspaces mediante un Policy Set. 
La política inspecciona cada plan y detecta si algún NSG expone el 
puerto SSH (22) a `0.0.0.0/0`, advirtiendo al equipo antes del apply.

```
sentinel/
    ├── sentinel.hcl                  # enforcement_level = "advisory"
    └── restrict-ssh-open.sentinel    # Detecta SSH abierto a Internet
```
El nivel de aplicación es `advisory` porque los runners de GitHub Actions 
utilizan IPs dinámicas que impiden restringir el acceso SSH a un rango fijo. 
En un entorno empresarial con runners autoalojados o Azure Bastion, 
el nivel se cambiaría a `enforcing`.

El resultado de la política aparece en la sección **Policy checks** 
de cada run de Terraform Cloud.

---

## Pipelines CI/CD

### CI — Plan especulativo (Pull Request)

Se dispara automáticamente al abrir una PR hacia `develop` o `main`.  
Terraform Cloud genera un **plan especulativo** que muestra qué recursos 
se crearían, modificarían o destruirían, sin aplicar ningún cambio real.  
Simultáneamente se ejecuta la **política Sentinel** en modo advisory.  
El resultado aparece como check en la PR de GitHub.

### CD — Apply (Merge)

Se dispara automáticamente al hacer merge a `develop` o `main`.  
Terraform Cloud ejecuta el **plan aplicable** y aprovisiona los recursos 
en Azure incluyendo el Key Vault y el secreto `eco-api-secret`.

### Ansible — Configuración de VM (Merge)

Se dispara en paralelo al CD de Terraform mediante el workflow `ansible.yml`.  
Espera a que Terraform termine el apply, obtiene la IP de la VM y la URI 
del Key Vault directamente desde la **API de Terraform Cloud** y ejecuta 
el playbook que:

- Instala Python 3, pip, venv, git, curl y Nginx
- Crea el directorio `/opt/microservicio`
- Genera el entorno virtual Python
- Instala FastAPI, Uvicorn y dependencias del SDK de Azure Key Vault
- Configura Nginx como proxy inverso hacia `localhost:8000`
- Configura el servicio **systemd** `microservicio` con las variables
  `ENTORNO=PRE/PRO` y `KEY_VAULT_URI=https://kv-tfg-<entorno>.vault.azure.net/`

---

## Secretos y variables necesarios

### En Terraform Cloud (por workspace)

**Variables de Terraform:**

| Variable | Descripción |
|---|---|
| `environment` | `pre` o `pro` |
| `project_name` | `tfg` |
| `location` | `SpainCentral` |
| `vm_size` | `Standard_B2s` |
| `admin_username` | `azureuser` |
| `key_vault_name` | Nombre único del Key Vault |
| `ssh_public_key` | Contenido de la clave pública RSA *(Sensitive)* |

**Variables de entorno** *(todas Sensitive)*:

| Variable | Descripción |
|---|---|
| `ARM_CLIENT_ID` | ID del Service Principal |
| `ARM_CLIENT_SECRET` | Password del Service Principal |
| `ARM_SUBSCRIPTION_ID` | ID de la suscripción Azure |
| `ARM_TENANT_ID` | ID del tenant Azure |

### En GitHub Actions (Repository secrets)

| Secret | Descripción |
|---|---|
| `SSH_PRIVATE_KEY` | Clave privada RSA para conectar a las VMs |
| `TF_API_TOKEN` | Token de API de Terraform Cloud |
| `AZURE_CREDENTIALS1` | JSON con credenciales del Service Principal |

### En GitHub Actions (Repository variables)

| Variable | Descripción |
|---|---|
| `TF_ORGANIZATION` | Nombre de la organización en Terraform Cloud |

---

## Primer despliegue

### 1. Clonar el repositorio
```bash
git clone https://github.com/javiergutierrezdelcaso/TFG-Infraestructura-Azure-Terraform.git
cd TFG-Infraestructura-Azure-Terraform
```

### 2. Configurar Terraform Cloud
- Crear dos workspaces: `TFG-Infraestructura-Azure-Terraform-PRE` 
  y `TFG-Infraestructura-Azure-Terraform-PRO`
- Conectar cada workspace a la rama correspondiente mediante VCS Provider
- Añadir todas las variables listadas en la sección anterior
- Crear un Policy Set llamado `tfg-seguridad-nsg` apuntando al 
  directorio `sentinel/` y asociarlo a ambos workspaces

### 3. Generar clave SSH RSA
```bash
ssh-keygen -t rsa -b 4096 -C "tfg-azure" -f ~/.ssh/id_rsa_tfg
cat ~/.ssh/id_rsa_tfg.pub   # → pegar en ssh_public_key de Terraform Cloud
cat ~/.ssh/id_rsa_tfg       # → pegar en SSH_PRIVATE_KEY de GitHub Actions
```

### 4. Añadir secretos en GitHub Actions
Ir a **Settings → Secrets and variables → Actions** y añadir 
`SSH_PRIVATE_KEY`, `TF_API_TOKEN` y `AZURE_CREDENTIALS1`.

### 5. Hacer push a develop
```bash
git checkout develop
git push origin develop
```
Terraform Cloud desplegará la infraestructura de PRE automáticamente, 
incluyendo el Key Vault y el secreto `eco-api-secret`. Ansible configurará 
la VM e inyectará la URI del Key Vault en el servicio systemd.

---

## Requisitos previos

- Cuenta en [GitHub](https://github.com)
- Cuenta en [Terraform Cloud](https://app.terraform.io)
- Suscripción activa en [Microsoft Azure](https://portal.azure.com)
- Service Principal de Azure con rol **Contributor** y permisos sobre Key Vault

---

## Referencias

- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Terraform Cloud VCS Provider](https://developer.hashicorp.com/terraform/cloud-docs/vcs/github-app)
- [Terraform Sentinel Documentation](https://developer.hashicorp.com/sentinel/docs)
- [Azure Key Vault Documentation](https://learn.microsoft.com/en-us/azure/key-vault)
- [Ansible Documentation](https://docs.ansible.com)
- [Azure Virtual Machines](https://learn.microsoft.com/en-us/azure/virtual-machines)

