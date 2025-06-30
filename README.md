# Deployment Guide for CLO835 Assignment 2 
![Push to ECR](https://github.com/albus-droid/assignment2/actions/workflows/main.yml/badge.svg)

This README provides step-by-step instructions to deploy your two-tier web application (MySQL + web) on a local Kind Kubernetes cluster running on an Amazon Linux EC2 instance. It also covers building and pushing Docker images to ECR, creating namespaces, ConfigMap, pull-secrets, applying manifests, and testing.

---

## Prerequisites

* **AWS CLI** configured with appropriate credentials
* **kubectl**, **kind**, **docker**, **git** installed on your EC2 instance
* **IAM Role** on EC2 with ECR permissions: `ecr:GetAuthorizationToken`, `ecr:BatchGetImage`, `ecr:GetDownloadUrlForLayer`
* **Security Group**: allow ports `22` (SSH) and `80` (HTTP)

---

## 0. Install Prerequisites (Docker, Git, kubectl, kind)
```bash
# Update and install Docker & Git
sudo yum update -y
sudo yum install -y docker git

# Add ec2-user to docker group
sudo usermod -aG docker ec2-user

# Start Docker
echo "Starting Docker..."
sudo systemctl enable --now docker

# Install kubectl
curl -Lo kubectl https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# Install Kind
curl -Lo kind "https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64"
chmod +x kind && sudo mv kind /usr/local/bin/
```

---

## 1. Create Kind Cluster

```bash
kind create cluster --name clo835 --config kind-config.yaml
```

> Ensure your `kind-config.yaml` has:
>
> ```yaml
> kind: Cluster
> apiVersion: kind.x-k8s.io/v1alpha4
> nodes:
> - role: control-plane
>   extraPortMappings:
>     - containerPort: 30000
>       hostPort: 80
>       protocol: TCP
> ```

---

## 2. Create Namespaces

```bash
kubectl apply -f k8s/namespaces/ns.yaml
```

This creates two namespaces:

* `mysql`
* `web`

---

## 3. Deploy ConfigMap (Application Configuration)

```bash
kubectl apply -f k8s/configmap/app-config.yaml
```

The ConfigMap stores available UI colors and the current selection:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: web
data:
  availableColors: "blue,green,red"
  currentColor: "green"
```

---

## 4. Create ECR Pull-Secrets

Authenticate to ECR and create a Kubernetes secret in both namespaces so Pods can pull private images.

```bash
# For mysql namespace
kubectl create secret docker-registry ecr-pull-secret \
  --docker-server=164340264957.dkr.ecr.us-east-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password="$(aws ecr get-login-password --region us-east-1)" \
  --docker-email=you@example.com \
  -n mysql

# For web namespace
kubectl create secret docker-registry ecr-pull-secret \
  --docker-server=164340264957.dkr.ecr.us-east-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password="$(aws ecr get-login-password --region us-east-1)" \
  --docker-email=you@example.com \
  -n web
```

---

## 5. Apply Kubernetes Manifests

> **Note:** Pods and ReplicaSets are optional if using Deployments only.

```bash
# (Optional) Pods
kubectl apply -f k8s/pods/

# (Optional) ReplicaSets
kubectl apply -f k8s/replicasets/

# Deployments
kubectl apply -f k8s/deployments/

# Services
kubectl apply -f k8s/services/
```

This will create:

* **Deployments** for MySQL and web (3 replicas each, rolling update strategy)
* **ClusterIP Service** for MySQL
* **NodePort Service** (port 30000) for web, exposed on VM port 80 via Kind mapping

---

## 6. Verify Deployment

```bash
kubectl get ns
kubectl get pods -n mysql
kubectl get pods -n web
kubectl get rs -n mysql -n web
kubectl get deploy -n mysql -n web
kubectl get svc -n mysql -n web
```

### Check Logs and Connectivity

```bash
# Logs from a web Pod
kubectl logs -n web <web-pod-name>

# Inside a web Pod
kubectl exec -n web <web-pod-name> -- curl -s localhost:8080

# From VM or laptop (HTTP on port 80)
curl http://<EC2_PUBLIC_IP>/
```

---

## 7. Change UI Color

To switch the theme color dynamically, patch the ConfigMap and roll out the update:

```bash
kubectl patch configmap app-config -n web \
  --type merge \
  -p '{"data":{"currentColor":"red"}}'

kubectl rollout restart deployment/web-deployment -n web
kubectl rollout status deployment/web-deployment -n web
```

> All three web replicas will restart one-by-one and pick up the new `APP_COLOR` value.

---

## References

* Kind: [https://kind.sigs.k8s.io/](https://kind.sigs.k8s.io/)
* Kubernetes Documentation: [https://kubernetes.io/docs/](https://kubernetes.io/docs/)
* AWS ECR: [https://docs.aws.amazon.com/AmazonECR/latest/userguide/using-authorization-token.html](https://docs.aws.amazon.com/AmazonECR/latest/userguide/using-authorization-token.html)

---

**End of README**
