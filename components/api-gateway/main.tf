# variables.tf
variable "aws_region" {
  description = "AWS Region"
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment configuration"
  type = object({
    api_name   = string
    stage_name = string
  })
  default = {
    api_name   = "Api-Gateway-grupo1a"
    stage_name = "public-prod"
  }
}

variable "existing_api_gateway_id" {
  description = "ID de un API Gateway existente. Si se proporciona, se actualizará en lugar de crear uno nuevo. Dejar vacío para crear uno nuevo."
  type        = string
  default     = "20a1r0o6ck"
}

variable "vpc_link_id" {
  description = "VPC Link ID"
  default     = "me89em"
}

variable "nlb_dns" {
  description = "NLB DNS name"
  default     = "nlb-apigateway-cm-grupo1a-ad8a0410a5bddba9.elb.us-east-1.amazonaws.com"
}

variable "nlb_arn" {
  description = "NLB ARN for integration target"
  default     = "arn:aws:elasticloadbalancing:us-east-1:200283853536:loadbalancer/net/nlb-apigateway-cm-grupo1a/ad8a0410a5bddba9"
}

# ============================================
# CONFIGURACIÓN DEL AUTHORIZER
# ============================================
variable "existing_authorizer_id" {
  description = "ID de un Authorizer existente. Si se proporciona, se usará en lugar de crear uno nuevo (y NO se crearán IAM Role, Policy ni Lambda Permission). Dejar vacío para crear uno nuevo."
  type        = string
  default     = "3vae12"
}

variable "authorizer_lambda_arn" {
  description = "ARN de la Lambda que actuará como authorizer. Requerido si existing_authorizer_id está vacío y hay endpoints con require_auth = true."
  type        = string
  default     = "arn:aws:lambda:us-east-1:200283853536:function:api-token-authorizer"
}

variable "authorizer_name" {
  description = "Nombre del authorizer a crear"
  type        = string
  default     = "TokenAuthorizer"
}

variable "authorizer_ttl" {
  description = "Tiempo en segundos que se cachea el resultado del authorizer"
  type        = number
  default     = 300
}

# ============================================
# CONFIGURACIÓN CORS POR DEFECTO
# ============================================
locals {
  default_cors = {
    allow_origins = "'*'"
    allow_methods = "'GET,POST,PUT,DELETE,OPTIONS'"
    allow_headers = "'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token'"
  }
}

# ============================================
# DEFINIR ENDPOINTS EN UN SOLO LUGAR
# ============================================
locals {
  endpoints = {
    # ============================================
    # ENDPOINTS VPC_LINK (Pod EKS)
    # lambda_arn = "" o no incluirlo significa VPC_LINK
    # ============================================
    health_get = {
      path         = "/api/health"
      method       = "GET"
      summary      = "Health check"
      operationId  = "getHealth"
      enable_cors  = true
      require_auth = false
      lambda_arn   = ""  # Vacío = VPC_LINK (Pod EKS)
    }
     entrega_get = {
      path         = "/api/entrega/v1.0.0/get"
      method       = "GET"
      summary      = "servicio de entrega"
      operationId  = "getEntrega"
      enable_cors  = true
      require_auth = true
      lambda_arn   = ""  # Vacío = VPC_LINK (Pod EKS)
    }
    encrypt_post = {
      path         = "/api/auth-server/v1.0.0/auth/encrypt"
      method       = "POST"
      summary      = "Encriptar datos"
      operationId  = "encryptData"
      enable_cors  = true
      require_auth = false
      lambda_arn   = "arn:aws:lambda:us-east-1:200283853536:function:auth-server"
    }
    decrypt_post = {
      path         = "/api/auth-server/v1.0.0/auth/decrypt"
      method       = "POST"
      summary      = "Desencriptar datos"
      operationId  = "decryptData"
      enable_cors  = true
      require_auth = false
      lambda_arn   = "arn:aws:lambda:us-east-1:200283853536:function:auth-server"
    }
    create_post = {
      path         = "/api/auth-server/v1.0.0/auth/create"
      method       = "POST"
      summary      = "Crear token de autenticación"
      operationId  = "createToken"
      enable_cors  = true
      require_auth = false
      lambda_arn   = "arn:aws:lambda:us-east-1:200283853536:function:auth-server"
    }
    login_post = {
      path         = "/api/auth-server/v1.0.0/auth/login"
      method       = "POST"
      summary      = "Autenticar usuario"
      operationId  = "loginUser"
      enable_cors  = true
      require_auth = false
      lambda_arn   = "arn:aws:lambda:us-east-1:200283853536:function:auth-server"
    }
    validate_get = {
      path         = "/api/auth-server/v1.0.0/auth/validate"
      method       = "GET"
      summary      = "Validar token"
      operationId  = "validateToken"
      enable_cors  = true
      require_auth = false
      lambda_arn   = "arn:aws:lambda:us-east-1:200283853536:function:auth-server"
    }
    refresh_get = {
      path         = "/api/auth-server/v1.0.0/auth/refresh"
      method       = "GET"
      summary      = "Refrescar token"
      operationId  = "refreshToken"
      enable_cors  = true
      require_auth = false
      lambda_arn   = "arn:aws:lambda:us-east-1:200283853536:function:auth-server"
    }
    # AGREGAR NUEVOS ENDPOINTS AQUÍ
    #
    # Opción 1: CORS por defecto, SIN autenticación
    # resource_get = {
    #   path         = "/api/ejemplo/v1.0.0/resource"
    #   method       = "GET"
    #   summary      = "Descripción del endpoint"
    #   operationId  = "ejemploOperation"
    #   enable_cors  = true
    #   require_auth = false
    # }
    #
    # Opción 2: CORS por defecto, CON autenticación
    # resource_secure = {
    #   path         = "/api/ejemplo/v1.0.0/secure"
    #   method       = "GET"
    #   summary      = "Endpoint protegido"
    #   operationId  = "secureOperation"
    #   enable_cors  = true
    #   require_auth = true  # Usará el authorizer configurado
    # }
    #
    # Opción 3: CORS personalizado
    # resource_post = {
    #   path         = "/api/ejemplo/v1.0.0/resource"
    #   method       = "POST"
    #   summary      = "Crear recurso"
    #   operationId  = "createResource"
    #   require_auth = true
    #   cors = {
    #     allow_origins = "'https://midominio.com'"
    #     allow_methods = "'GET,POST'"
    #     allow_headers = "'Content-Type,Authorization'"
    #   }
    # }
    #
    # Opción 4: Sin CORS (no agregar enable_cors ni cors)
  }

  # Función helper para obtener configuración CORS de un endpoint
  get_cors_config = {
    for key, endpoint in local.endpoints : key => (
      lookup(endpoint, "cors", null) != null ? endpoint.cors : (
        lookup(endpoint, "enable_cors", false) ? local.default_cors : null
      )
    )
  }

  # Verificar si un endpoint tiene CORS habilitado
  has_cors = {
    for key, endpoint in local.endpoints : key => (
      lookup(endpoint, "cors", null) != null || lookup(endpoint, "enable_cors", false)
    )
  }
}

# ============================================
# GENERAR OPENAPI SPEC DINÁMICAMENTE
# ============================================
locals {
  # Agrupar endpoints por path para soportar múltiples métodos
  endpoints_by_path = {
    for path in distinct([for k, v in local.endpoints : v.path]) : path => {
      for key, endpoint in local.endpoints : lower(endpoint.method) => merge(
        endpoint,
        { _key = key }  # Guardar la key original para acceder a get_cors_config
      )
      if endpoint.path == path
    }
  }

  # Obtener la configuración CORS para cada path (usa el primer endpoint con CORS del path)
  cors_config_by_path = {
    for path in distinct([for k, v in local.endpoints : v.path]) : path => (
      length([for key, endpoint in local.endpoints : local.get_cors_config[key]
       if endpoint.path == path && local.get_cors_config[key] != null]) > 0
      ? [for key, endpoint in local.endpoints : local.get_cors_config[key]
         if endpoint.path == path && local.get_cors_config[key] != null][0]
      : null
    )
  }

  openapi_spec = {
    openapi = "3.0.1"
    info = {
      title       = var.environment.api_name
      description = "API REST GRUPO 1A DIPLOMADO"
      version     = "1.0.0"
    }

    paths = {
      for path, methods in local.endpoints_by_path : path => merge(
        # Métodos principales (GET, POST, PUT, DELETE)
        {
          for method, endpoint in methods : method => {
            summary     = endpoint.summary
            operationId = endpoint.operationId
            responses = {
              "200" = merge(
                {
                  description = "Successful response"
                  content = {
                    "application/json" = {
                      schema = { type = "object" }
                    }
                  }
                },
                # Headers CORS en respuesta si está habilitado
                local.has_cors[endpoint._key] ? {
                  headers = {
                    Access-Control-Allow-Origin = {
                      schema = { type = "string" }
                    }
                  }
                } : {}
              )
            }
            x-amazon-apigateway-integration = {
              type                = "MOCK"
              passthroughBehavior = "WHEN_NO_MATCH"
              requestTemplates = {
                "application/json" = "{\"statusCode\": 200}"
              }
            }
          }
        },
        # Método OPTIONS para CORS (si algún endpoint del path tiene CORS)
        anytrue([for m, e in methods : local.has_cors[e._key]]) ? {
          options = {
            summary     = "CORS preflight"
            operationId = "options${replace(title(replace(path, "/", " ")), " ", "")}"
            responses = {
              "200" = {
                description = "CORS preflight response"
                headers = {
                  Access-Control-Allow-Origin = {
                    schema = { type = "string" }
                  }
                  Access-Control-Allow-Methods = {
                    schema = { type = "string" }
                  }
                  Access-Control-Allow-Headers = {
                    schema = { type = "string" }
                  }
                }
              }
            }
            x-amazon-apigateway-integration = {
              type = "MOCK"
              requestTemplates = {
                "application/json" = "{\"statusCode\": 200}"
              }
              responses = {
                default = {
                  statusCode = "200"
                  responseParameters = {
                    "method.response.header.Access-Control-Allow-Headers" = "'${try(local.cors_config_by_path[path].allow_headers, local.default_cors.allow_headers)}'"
                    "method.response.header.Access-Control-Allow-Methods" = "'${try(local.cors_config_by_path[path].allow_methods, local.default_cors.allow_methods)}'"
                    "method.response.header.Access-Control-Allow-Origin"  = "'${try(local.cors_config_by_path[path].allow_origins, local.default_cors.allow_origins)}'"
                  }
                  responseTemplates = {
                    "application/json" = ""
                  }
                }
              }
            }
          }
        } : {}
      )
    }

    x-amazon-apigateway-endpoint-configuration = {
      types = ["REGIONAL"]
    }
  }
}

# ============================================
# API GATEWAY REST API
# ============================================

# Crear nuevo API Gateway SOLO si no se proporciona un ID existente
resource "aws_api_gateway_rest_api" "cash_management" {
  count = var.existing_api_gateway_id == "" ? 1 : 0
  name  = var.environment.api_name
  body  = jsonencode(local.openapi_spec)

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Actualizar API Gateway existente usando AWS CLI (si se proporciona ID)
# IMPORTANTE: Usamos --mode merge para NO eliminar recursos existentes como authorizers
resource "null_resource" "update_existing_api" {
  count = var.existing_api_gateway_id != "" ? 1 : 0

  triggers = {
    api_id       = var.existing_api_gateway_id
    openapi_spec = sha1(jsonencode(local.openapi_spec))
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e
      echo "Verificando identidad AWS..."
      aws sts get-caller-identity --region ${var.aws_region}
      cat > /tmp/openapi_spec_${var.existing_api_gateway_id}.json << 'EOFSPEC'
${jsonencode(local.openapi_spec)}
EOFSPEC
      echo "Actualizando API Gateway ${var.existing_api_gateway_id}..."
      aws apigateway put-rest-api \
        --rest-api-id ${var.existing_api_gateway_id} \
        --mode merge \
        --fail-on-warnings \
        --body fileb:///tmp/openapi_spec_${var.existing_api_gateway_id}.json \
        --region ${var.aws_region}
      rm -f /tmp/openapi_spec_${var.existing_api_gateway_id}.json
      echo "API Gateway actualizado exitosamente."
    EOT
  }
}

# Local para acceder al ID del API Gateway (existente o nuevo)
locals {
  api_gateway_id  = var.existing_api_gateway_id != "" ? var.existing_api_gateway_id : aws_api_gateway_rest_api.cash_management[0].id
  api_gateway_arn = var.existing_api_gateway_id != "" ? "arn:aws:apigateway:${var.aws_region}::/restapis/${var.existing_api_gateway_id}" : aws_api_gateway_rest_api.cash_management[0].arn
}

# ============================================
# LAMBDA AUTHORIZER
# ============================================

locals {
  endpoints_require_auth = anytrue([for k, v in local.endpoints : lookup(v, "require_auth", false)])

  # Usar authorizer existente si se proporciona un ID
  use_existing_authorizer = var.existing_authorizer_id != ""

  # Crear authorizer SOLO si no se proporciona un ID existente Y hay endpoints que requieren auth
  create_authorizer = !local.use_existing_authorizer && local.endpoints_require_auth && var.authorizer_lambda_arn != ""

  # ID del authorizer a usar (existente o creado)
  authorizer_id = local.use_existing_authorizer ? var.existing_authorizer_id : (
    local.create_authorizer ? aws_api_gateway_authorizer.lambda_authorizer[0].id : ""
  )
}

# Crear el authorizer SOLO si no se proporciona uno existente
# NOTA: Los permisos de Lambda (aws_lambda_permission), IAM Role y Policy
# se gestionan desde OTRO Terraform donde se crea la Lambda.
resource "aws_api_gateway_authorizer" "lambda_authorizer" {
  count                            = local.create_authorizer ? 1 : 0
  name                             = var.authorizer_name
  rest_api_id                      = local.api_gateway_id
  authorizer_uri                   = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${var.authorizer_lambda_arn}/invocations"
  authorizer_result_ttl_in_seconds = var.authorizer_ttl
  identity_source                  = "method.request.header.Authorization"
  type                             = "TOKEN"

  # Evitar recreación innecesaria
  lifecycle {
    ignore_changes = [rest_api_id]
  }

  depends_on = [
    aws_api_gateway_rest_api.cash_management,
    null_resource.update_existing_api
  ]
}

# ============================================
# CONFIGURAR INTEGRACIONES DINÁMICAMENTE
# ============================================

# Separar endpoints por tipo de integración
locals {
  # Endpoints que van a VPC_LINK (Pod EKS) - lambda_arn vacío o no definido
  endpoints_vpc_link = {
    for k, v in local.endpoints : k => v
    if lookup(v, "lambda_arn", "") == ""
  }

  # Endpoints que van a Lambda (AWS_PROXY) - lambda_arn con valor
  endpoints_lambda = {
    for k, v in local.endpoints : k => v
    if lookup(v, "lambda_arn", "") != ""
  }

  # Determinar si hay un authorizer disponible (existente o creado)
  has_authorizer = local.use_existing_authorizer || local.create_authorizer

  # Filtrar endpoints con require_auth = true
  endpoints_with_auth = {
    for k, v in local.endpoints : k => v
    if lookup(v, "require_auth", false) && local.has_authorizer
  }
}

# Función helper bash para resolver resource IDs en tiempo de ejecución
locals {
  # Script helper que obtiene todos los resource IDs del API Gateway y los cachea
  get_resource_id_helper = <<-BASH
    get_resource_id() {
      local api_id="$1"
      local path="$2"
      local region="$3"
      local resource_id
      resource_id=$(aws apigateway get-resources \
        --rest-api-id "$api_id" \
        --region "$region" \
        --query "items[?path=='$path'].id | [0]" \
        --output text)
      if [ -z "$resource_id" ] || [ "$resource_id" = "None" ]; then
        echo "ERROR: No se encontró resource ID para path: $path" >&2
        return 1
      fi
      echo "$resource_id"
    }
  BASH
}

# Ejecutar integraciones VPC_LINK (Pod EKS)
resource "null_resource" "integrations_vpc_link" {
  count = length(local.endpoints_vpc_link) > 0 ? 1 : 0

  depends_on = [
    aws_api_gateway_rest_api.cash_management,
    null_resource.update_existing_api
  ]

  triggers = {
    rest_api_id = local.api_gateway_id
    nlb_arn     = var.nlb_arn
    endpoints   = sha1(jsonencode(local.endpoints_vpc_link))
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e
      ${local.get_resource_id_helper}
      %{for key, endpoint in local.endpoints_vpc_link~}
      echo "Obteniendo resource ID para ${endpoint.path}..."
      RESOURCE_ID=$(get_resource_id "${local.api_gateway_id}" "${endpoint.path}" "${var.aws_region}")
      echo "Resource ID: $RESOURCE_ID"
      echo "Ejecutando integración VPC_LINK para ${endpoint.path}..."
      aws apigateway put-integration \
        --rest-api-id ${local.api_gateway_id} \
        --resource-id "$RESOURCE_ID" \
        --http-method ${endpoint.method} \
        --type HTTP_PROXY \
        --integration-http-method ${endpoint.method} \
        --uri 'http://$${stageVariables.NLB_DNS}${endpoint.path}' \
        --connection-type VPC_LINK \
        --connection-id '$${stageVariables.VPC_LINK}' \
        --integration-target ${var.nlb_arn} \
        --region ${var.aws_region}
      sleep 1
      %{endfor~}
      echo "Todas las integraciones VPC_LINK completadas"
    EOT
  }
}

# Ejecutar integraciones Lambda (AWS_PROXY)
resource "null_resource" "integrations_lambda" {
  count = length(local.endpoints_lambda) > 0 ? 1 : 0

  depends_on = [
    aws_api_gateway_rest_api.cash_management,
    null_resource.update_existing_api
  ]

  triggers = {
    rest_api_id = local.api_gateway_id
    endpoints   = sha1(jsonencode(local.endpoints_lambda))
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e
      ${local.get_resource_id_helper}
      %{for key, endpoint in local.endpoints_lambda~}
      echo "Obteniendo resource ID para ${endpoint.path}..."
      RESOURCE_ID=$(get_resource_id "${local.api_gateway_id}" "${endpoint.path}" "${var.aws_region}")
      echo "Resource ID: $RESOURCE_ID"
      echo "Ejecutando integración Lambda para ${endpoint.path}..."
      aws apigateway put-integration \
        --rest-api-id ${local.api_gateway_id} \
        --resource-id "$RESOURCE_ID" \
        --http-method ${endpoint.method} \
        --type AWS_PROXY \
        --integration-http-method POST \
        --uri 'arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${endpoint.lambda_arn}/invocations' \
        --region ${var.aws_region}
      sleep 1
      %{endfor~}
      echo "Todas las integraciones Lambda completadas"
    EOT
  }
}

# ============================================
# CONFIGURAR AUTHORIZER EN MÉTODOS
# ============================================
# Configurar el authorizer en los métodos que lo requieren
resource "null_resource" "method_authorizer" {
  count = (local.use_existing_authorizer || local.create_authorizer) && local.endpoints_require_auth ? 1 : 0

  depends_on = [
    null_resource.integrations_vpc_link,
    null_resource.integrations_lambda,
    aws_api_gateway_authorizer.lambda_authorizer
  ]

  triggers = {
    rest_api_id   = local.api_gateway_id
    authorizer_id = local.authorizer_id
    endpoints     = sha1(jsonencode(local.endpoints_with_auth))
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e
      ${local.get_resource_id_helper}
      %{for key, endpoint in local.endpoints_with_auth~}
      echo "Obteniendo resource ID para ${endpoint.path}..."
      RESOURCE_ID=$(get_resource_id "${local.api_gateway_id}" "${endpoint.path}" "${var.aws_region}")
      echo "Configurando authorizer en ${endpoint.method} ${endpoint.path}..."
      aws apigateway update-method \
        --rest-api-id ${local.api_gateway_id} \
        --resource-id "$RESOURCE_ID" \
        --http-method ${endpoint.method} \
        --patch-operations \
          op=replace,path=/authorizationType,value=CUSTOM \
          op=replace,path=/authorizerId,value=${local.authorizer_id} \
        --region ${var.aws_region}
      sleep 1
      %{endfor~}
      echo "Todos los authorizers configurados"
    EOT
  }
}

# ============================================
# DEPLOYMENT & STAGE
# ============================================
resource "aws_api_gateway_deployment" "main" {
  rest_api_id = local.api_gateway_id

  triggers = {
    redeployment = sha1(jsonencode([
      var.nlb_arn,
      var.nlb_dns,
      var.vpc_link_id,
      local.openapi_spec,
      local.endpoints,
      var.existing_api_gateway_id,
      var.existing_authorizer_id,
      var.authorizer_lambda_arn,
      local.authorizer_id
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    null_resource.integrations_vpc_link,
    null_resource.integrations_lambda,
    null_resource.method_authorizer
  ]
}

# Crear stage solo si es un API Gateway nuevo
resource "aws_api_gateway_stage" "dev" {
  count         = var.existing_api_gateway_id == "" ? 1 : 0
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = local.api_gateway_id
  stage_name    = var.environment.stage_name

  variables = {
    VPC_LINK = var.vpc_link_id
    NLB_DNS  = var.nlb_dns
  }
}

# Crear o actualizar stage existente usando AWS CLI (si se proporciona ID de API existente)
resource "null_resource" "update_existing_stage" {
  count = var.existing_api_gateway_id != "" ? 1 : 0

  triggers = {
    deployment_id = aws_api_gateway_deployment.main.id
    vpc_link_id   = var.vpc_link_id
    nlb_dns       = var.nlb_dns
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      # Verificar si el stage existe
      STAGE_EXISTS=$(aws apigateway get-stage \
        --rest-api-id ${var.existing_api_gateway_id} \
        --stage-name ${var.environment.stage_name} \
        --region ${var.aws_region} 2>&1)

      if echo "$STAGE_EXISTS" | grep -q "NotFoundException"; then
        echo "Stage '${var.environment.stage_name}' no existe. Creando..."
        aws apigateway create-stage \
          --rest-api-id ${var.existing_api_gateway_id} \
          --stage-name ${var.environment.stage_name} \
          --deployment-id ${aws_api_gateway_deployment.main.id} \
          --variables VPC_LINK=${var.vpc_link_id},NLB_DNS=${var.nlb_dns} \
          --region ${var.aws_region}
        echo "Stage '${var.environment.stage_name}' creado exitosamente."
      else
        echo "Stage '${var.environment.stage_name}' existe. Actualizando..."
        aws apigateway update-stage \
          --rest-api-id ${var.existing_api_gateway_id} \
          --stage-name ${var.environment.stage_name} \
          --patch-operations \
            op=replace,path=/deploymentId,value=${aws_api_gateway_deployment.main.id} \
            op=replace,path=/variables/VPC_LINK,value=${var.vpc_link_id} \
            op=replace,path=/variables/NLB_DNS,value=${var.nlb_dns} \
          --region ${var.aws_region}
        echo "Stage '${var.environment.stage_name}' actualizado exitosamente."
      fi
    EOT
  }

  depends_on = [aws_api_gateway_deployment.main]
}

# ============================================
# OUTPUTS
# ============================================
output "api_gateway_url" {
  description = "API Gateway Invoke URL"
  value       = var.existing_api_gateway_id != "" ? "https://${var.existing_api_gateway_id}.execute-api.${var.aws_region}.amazonaws.com/${var.environment.stage_name}" : aws_api_gateway_stage.dev[0].invoke_url
}

output "api_gateway_id" {
  description = "API Gateway ID"
  value       = local.api_gateway_id
}

output "api_gateway_arn" {
  description = "API Gateway ARN"
  value       = local.api_gateway_arn
}

output "is_existing_api" {
  description = "Indica si se está usando un API Gateway existente"
  value       = var.existing_api_gateway_id != ""
}

output "authorizer_id" {
  description = "ID del Authorizer (existente o creado)"
  value       = local.authorizer_id
}

output "is_existing_authorizer" {
  description = "Indica si se está usando un Authorizer existente"
  value       = local.use_existing_authorizer
}

output "endpoints_with_auth" {
  description = "Lista de endpoints que requieren autenticación"
  value       = [for k, v in local.endpoints : v.path if lookup(v, "require_auth", false)]
}

output "endpoints_vpc_link" {
  description = "Lista de endpoints que usan VPC_LINK (Pod EKS)"
  value       = [for k, v in local.endpoints_vpc_link : v.path]
}

output "endpoints_lambda" {
  description = "Lista de endpoints que usan integración Lambda"
  value       = [for k, v in local.endpoints_lambda : "${v.path} -> ${v.lambda_arn}"]
}
