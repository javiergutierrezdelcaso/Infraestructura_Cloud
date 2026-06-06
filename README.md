# 🏗️ EcoAnalyzer — Infraestructura Cloud

Repositorio de Infraestructura como Código (IaC) del proyecto **EcoAnalyzer**, 
desarrollado como Trabajo de Fin de Grado en Ingeniería Informática.

Gestiona el aprovisionamiento automatizado de recursos en **Microsoft Azure** 
mediante **Terraform** y la configuración de servidores mediante **Ansible**, 
integrados en pipelines CI/CD que se disparan automáticamente con cada cambio en el repositorio.

![Ansible](https://github.com/javiergutierrezdelcaso/tfg-infraestructura-azure-terraform/actions/workflows/ansible.yml/badge.svg)
---

## Arquitectura

```
GitHub (push/PR)
    │
    ├── Terraform Cloud ──────────────────────► Azure
    │   ├── PR → Plan especulativo (CI)              ├── Resource Group
    │   └── Merge → Apply (CD)                       ├── Red Virtual + Subred
    │                                                ├── IP Pública Estática
    └── GitHub Actions                               ├── Network Security Group
        └── Merge → Ansible                          ├── Máquina Virtual Ubuntu 22.04
                    └── Configura la VM              └── Azure Key Vault
```

---

## Entornos

| Entorno | Rama | Workspace Terraform Cloud | Resource Group |
|---|---|---|---|
| **PRE** (Preproducción) | `develop` | `Infraestructura_Pre` | `rg-tfg-pre` |
| **PRO** (Producción) | `main` | `Infraestructura_Pro` | `rg-tfg-pro` |

---

## Estructura del repositorio

```
Infraestructura_Cloud/
├── providers.tf              # Proveedor azurerm + conexión Terraform Cloud
├── variables.tf              # Declaración de variables con validaciones
├── main.tf                   # Recursos de Azure (VM, red, NSG, Key Vault)
├── outputs.tf                # Outputs: IP pública, nombre de recursos
├── .gitignore                # Excluye .tfvars, .tfstate, .terraform/
├── terraform.tfvars.example  # Ejemplo de variables (no subir valores reales)
└── ansible/
    ├── playbook.yml          # Playbook principal
    ├── inventory.ini         # Inventario local (desarrollo)
    └── roles/
        └── microservicio/
            └── tasks/
                └── main.yml  # Instala Python, FastAPI, configura systemd
```

---

## Recursos aprovisionados por Terraform

| Recurso | Nombre (PRE / PRO) |
|---|---|
| Resource Group | `rg-tfg-pre` / `rg-tfg-pro` |
| Red Virtual | `vnet-tfg-pre` / `vnet-tfg-pro` |
| Subred | `snet-tfg-pre` / `snet-tfg-pro` |
| IP Pública Estática | `pip-tfg-pre` / `pip-tfg-pro` |
| Network Security Group | `nsg-tfg-pre` / `nsg-tfg-pro` |
| Interfaz de Red | `nic-tfg-pre` / `nic-tfg-pro` |
| Máquina Virtual Ubuntu 22.04 | `vm-tfg-pre` / `vm-tfg-pro` |
| Azure Key Vault | `kv-tfg-pre` / `kv-tfg-pro` |

El NSG permite tráfico entrante en el **puerto 22** (SSH) y **puerto 8000** (FastAPI).

---

## Pipelines CI/CD

### CI — Plan especulativo (Pull Request)

Se dispara automáticamente al abrir una PR hacia `develop` o `main`.  
Terraform Cloud genera un **plan especulativo** que muestra qué recursos 
se crearían, modificarían o destruirían, sin aplicar ningún cambio real.  
El resultado aparece como check en la PR de GitHub.

### CD — Apply (Merge)

Se dispara automáticamente al hacer merge a `develop` o `main`.  
Terraform Cloud ejecuta el **plan aplicable** y aprovisiona los recursos en Azure.  
En la interfaz de Terraform Cloud aparece el botón **Apply** para confirmar.

### Ansible — Configuración de VM (Merge)

Se dispara en paralelo al CD de Terraform mediante el workflow `ansible.yml`.  
Espera a que Terraform termine el apply, obtiene la IP de la VM directamente 
desde **Azure CLI** y ejecuta el playbook que:

- Instala Python 3, pip, venv, git y curl
- Crea el directorio `/opt/microservicio`
- Genera el entorno virtual Python
- Instala FastAPI y Uvicorn
- Configura el servicio **systemd** `microservicio` con la variable `ENTORNO=PRE/PRO`

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
| `allowed_ssh_ip` | IP permitida para SSH |
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
git clone https://github.com/TU_USUARIO/Infraestructura_Cloud.git
cd Infraestructura_Cloud
```

### 2. Configurar Terraform Cloud
- Crear dos workspaces: `Infraestructura_Pre` y `Infraestructura_Pro`
- Conectar cada workspace a la rama correspondiente mediante VCS Provider
- Añadir todas las variables listadas en la sección anterior

### 3. Generar clave SSH RSA
```bash
ssh-keygen -t rsa -b 4096 -C "tfg-azure" -f ~/.ssh/id_rsa_tfg
cat ~/.ssh/id_rsa_tfg.pub   # → pegar en ssh_public_key de Terraform Cloud
cat ~/.ssh/id_rsa_tfg       # → pegar en SSH_PRIVATE_KEY de GitHub Actions
```

### 4. Añadir secretos en GitHub Actions
Ir a Settings → Secrets and variables → Actions y añadir 
`SSH_PRIVATE_KEY`, `TF_API_TOKEN` y `AZURE_CREDENTIALS1`.

### 5. Hacer push a develop
```bash
git checkout develop
git push origin develop
```
Terraform Cloud desplegará la infraestructura de PRE automáticamente.

---

## Requisitos previos

- Cuenta en [GitHub](https://github.com)
- Cuenta en [Terraform Cloud](https://app.terraform.io)
- Suscripción activa en [Microsoft Azure](https://portal.azure.com)
- Service Principal de Azure con rol Contributor

---

## Referencias

- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Terraform Cloud VCS Provider](https://developer.hashicorp.com/terraform/cloud-docs/vcs/github-app)
- [Ansible Documentation](https://docs.ansible.com)
- [Azure Virtual Machines](https://learn.microsoft.com/en-us/azure/virtual-machines)
