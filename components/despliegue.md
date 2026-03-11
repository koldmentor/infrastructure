# Guía de Despliegue - Diplomado Grupo 1A

Orden de ejecución de los componentes Terraform. Cada componente depende de los anteriores.

## Prerequisito — Seleccionar cuenta AWS

Ejecutar antes de cualquier comando Terraform:

```bash
export AWS_PROFILE=escolar
```

Verificar que estás usando la cuenta correcta:

```bash
aws sts get-caller-identity
```

La salida debe mostrar el `Account` y el `Arn` correspondientes a la cuenta escolar.

---

## Paso 1 — VPC

> Sin dependencias. Debe ejecutarse primero.

```bash
cd vpc
terraform init
terraform apply
```

---

## Paso 2 — IAM

> Sin dependencias. Puede ejecutarse en paralelo con VPC.

```bash
cd iam
terraform init
terraform apply
```

---

## Paso 3 — RDS MySQL + SNS + SQS

> Pueden ejecutarse en paralelo entre sí.

### RDS MySQL

> Requiere outputs de: __vpc__ (`vpc_id`, `private_subnet_ids`). Puede ejecutarse en paralelo con EKS.
> Requiere `mysql` client instalado para la creación automática de tablas.

```bash
cd rds
terraform init
terraform apply
```

### SNS (Topics)

> Sin dependencias de otros componentes. Los permisos IAM ya incluyen acceso a `prod-*`.

```bash
cd sns
terraform init
terraform apply
```

### SQS (Colas)

> Sin dependencias de otros componentes. Los permisos IAM ya incluyen acceso a `prod-*`.
> Crea automáticamente Dead Letter Queues (DLQ) para las colas que lo tengan habilitado.

```bash
cd sqs
terraform init
terraform apply
```

---

## Paso 4 — EKS

> Requiere outputs de: **vpc** e **iam**

```bash
cd eks
terraform init
terraform apply
```

---

## Paso 5 — LB Controller + Fargate Logging + ALB Security Groups

> Pueden ejecutarse en paralelo entre sí.

### lb-controller

> Requiere outputs de: **eks** y **vpc**

```bash
cd lb-controller
terraform init
terraform apply
```

### fargate-logging

> Requiere outputs de: **eks**

```bash
cd fargate-logging
terraform init
terraform apply
```

### alb-security-groups

> Requiere outputs de: **vpc**

```bash
cd alb-security-groups
terraform init
terraform apply
```

---

## Paso 6 — ALB Initializer (kubectl)

> Requiere que el LB Controller esté corriendo. Despliega el servicio dummy que crea el ALB de Kubernetes.

```bash
aws eks update-kubeconfig --name eks-cm-grupo1a-prod --region us-east-1
kubectl apply -f ../Manifests/Api-health.yaml
kubectl get pods -n grupo1a-ms -w
kubectl get ingress -n grupo1a-ms
```

---

## Paso 7 — NLB

> Requiere outputs de: **vpc**, **eks** y que el ALB de Kubernetes esté activo (Paso 6)

```bash
cd nlb
terraform init
terraform apply
```

---

## Paso 8 — VPC Link

> Requiere outputs de: **nlb** y **vpc**

```bash
cd vpc-link
terraform init
terraform apply
```

---

## Paso 9 — API Gateway

> Requiere outputs de: **vpc-link** y **nlb**

```bash
cd api-gateway
terraform init
terraform apply
```

---

## Paso 10 — CloudFront (VPC Origin)

> Requiere que el ALB de Kubernetes esté activo (Paso 6). Puede ejecutarse en paralelo con los pasos 7-9.
> Conecta CloudFront directamente al ALB interno via VPC Origins, sin exponer el ALB a internet.

```bash
cd cloudfront
terraform init
terraform apply
```

---

## Destroy — Orden inverso

> El destroy debe ejecutarse en orden **inverso** al despliegue para respetar las dependencias.

### Paso 10 — CloudFront

```bash
cd cloudfront
terraform destroy
```

### Paso 9 — API Gateway

```bash
cd api-gateway
terraform destroy
```

### Paso 8 — VPC Link

```bash
cd vpc-link
terraform destroy
```

### Paso 7 — NLB

```bash
cd nlb
terraform destroy
```

### Paso 6 — ALB Initializer (kubectl)

```bash
kubectl delete -f ../Manifests/Api-health.yaml
```

### Paso 5 — LB Controller + Fargate Logging + ALB Security Groups

> Pueden destruirse en paralelo entre sí.

```bash
cd lb-controller
terraform destroy
```

```bash
cd fargate-logging
terraform destroy
```

```bash
cd alb-security-groups
terraform destroy
```

### Paso 4 — EKS

```bash
cd eks
terraform destroy
```

### Paso 3 — RDS MySQL + SNS + SQS

> Pueden destruirse en paralelo entre sí.

```bash
cd rds
terraform destroy
```

```bash
cd sns
terraform destroy
```

```bash
cd sqs
terraform destroy
```

### Paso 2 — IAM

```bash
cd iam
terraform destroy
```

### Paso 1 — VPC

```bash
cd vpc
terraform destroy
```

---

## Resumen del flujo de dependencias

```ini
vpc ──────────────────────────────────────────────────────────────┐
 ├── rds (MySQL - DBMySQLGrupo1a)                                │
 │                                                                │
sns (prod-package-events, prod-notifications)  ── sin deps        │
sqs (prod-packages-queue + DLQ)                ── sin deps        │
                                                                  │
iam ──────────────┐                                               │
                  ▼                                               │
                 eks ──── lb-controller                           │
                  │  └─── fargate-logging                         │
                  │                                               │
                  └──────────────────── alb-security-groups       │
                                                                  │
                                              kubectl apply ◄─────┘
                                           (Api-health.yaml)
                                                  │
                                         ┌────────┴────────┐
                                         ▼                 ▼
                                        nlb            cloudfront
                                         │          (VPC Origin → ALB)
                                         ▼
                                     vpc-link
                                         │
                                         ▼
                                    api-gateway
```
