# Guía de Conexión a la Base de Datos RDS - MySQL (Grupo 1A)

Para que un nuevo integrante del equipo pueda conectarse a la base de datos, hay que hacer dos cosas: autorizar su IP en AWS y configurar el cliente SQL.

---

## 1. Agregar la IP al Security Group

### Obtener la IP pública

Según el sistema operativo, abrir una terminal y ejecutar:

**Linux / macOS:**
```bash
curl ifconfig.me
```

**Windows (PowerShell):**
```powershell
Invoke-RestMethod ifconfig.me
```

**Windows (CMD):**
```cmd
nslookup myip.opendns.com resolver1.opendns.com
```

### Autorizar la IP en AWS

Una vez obtenida la IP, se agrega al Security Group. Esto lo puede hacer cualquiera que tenga permisos en AWS:

```bash
aws ec2 authorize-security-group-ingress \
  --group-id sg-0e0116dce4e5c303f \
  --protocol tcp \
  --port 3306 \
  --cidr IP_PUBLICA/32
```

> Reemplazar `IP_PUBLICA` por la IP real que arrojó el comando anterior.

---

## 2. Configurar DBeaver (o cualquier cliente SQL)

Datos de conexión:

| Parámetro  | Valor |
|------------|-------|
| Host       | `rds-mysql-grupo1a-prod.cgd20mcyuxjl.us-east-1.rds.amazonaws.com` |
| Port       | `3306` |
| Database   | `DBMySQLGrupo1a` |
| Username   | `admin_grupo1a` |
| Password   | El que se configuró en Terraform |

Con eso debería conectar sin problema.

---

## Recomendación: manejar las IPs desde Terraform

Para evitar agregar IPs manualmente cada vez, lo ideal es definirlas como variable en Terraform. Así quedan versionadas en el repo y no se pierden en futuros `terraform apply`:

```hcl
variable "allowed_ips" {
  default = [
    "181.130.112.222/32",  # Osneider
    "X.X.X.X/32"           # Compañero
  ]
}
```

Luego en el recurso del Security Group se recorren con `for_each` o `count` para crear una regla por cada IP.
