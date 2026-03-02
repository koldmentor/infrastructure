# Despliegue de Manifests

## Prerequisito

```bash
export AWS_PROFILE=escolar
aws eks update-kubeconfig --name eks-cm-grupo1a-prod --region us-east-1
```

## Aplicar manifiesto

```bash
kubectl apply -f api-health.yaml
```

## Verificar estado

```bash
kubectl get pods -n grupo1a-ms
kubectl get ingress -n grupo1a-ms
```

## Eliminar manifiesto

```bash
kubectl delete -f api-health.yaml
```
