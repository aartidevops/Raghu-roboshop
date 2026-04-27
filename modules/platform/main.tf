# modules/platform/main.tf
# Installs: cert-manager, nginx ingress, ArgoCD, Vault, Prometheus+Grafana
# Everything via Helm releases — zero CLI commands needed

# ─────────────────────────────────────────────────────────────────────────────
# NAMESPACE CREATION
# Create all namespaces first before installing anything
# kubernetes_namespace resource = kubectl create namespace
# ─────────────────────────────────────────────────────────────────────────────

resource "kubernetes_namespace" "cert_manager" {
  metadata { name = "cert-manager" }
}

resource "kubernetes_namespace" "ingress_nginx" {
  metadata { name = "ingress-nginx" }
}

resource "kubernetes_namespace" "argocd" {
  metadata { name = "argocd" }
}

resource "kubernetes_namespace" "vault" {
  metadata { name = "vault" }
}

resource "kubernetes_namespace" "monitoring" {
  metadata { name = "monitoring" }
}

resource "kubernetes_namespace" "roboshop" {
  metadata {
    name = "roboshop"
    labels = {
      # This label tells Vault injector to watch this namespace for pods
      "vault.io/enabled" = "true"
    }
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# CERT-MANAGER
# Issues free TLS certificates from Let's Encrypt
# Without this: no HTTPS, browsers show "Not Secure" warnings
# With this: certificates auto-issued and auto-renewed every 90 days
# ─────────────────────────────────────────────────────────────────────────────

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.16.0"
  namespace  = kubernetes_namespace.cert_manager.metadata[0].name

  set {
    name  = "crds.enabled"
    value = "true"
    # CRDs = Custom Resource Definitions
    # These add new resource types to Kubernetes:
    # Certificate, ClusterIssuer, CertificateRequest, Order, Challenge
    # Without crds.enabled=true, cert-manager installs but nothing works
  }

  set {
    name  = "global.leaderElection.namespace"
    value = "cert-manager"
  }

  # wait = true means Terraform waits until all pods are Running before continuing
  # If we didn't wait, the ClusterIssuer below would fail because cert-manager isn't ready
  wait    = true
  timeout = 300   # 5 minutes max
}

# ClusterIssuer — tells cert-manager HOW to get certificates
# ClusterIssuer (not Issuer) works across ALL namespaces — one config serves everything
# Real companies always use ClusterIssuer, not namespace-scoped Issuer
resource "kubernetes_manifest" "cluster_issuer_prod" {
  depends_on = [helm_release.cert_manager]

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        # Let's Encrypt FREE certificate authority
        # Rate limit: 50 certs per domain per week
        # Use staging server while testing: https://acme-staging-v02.api.letsencrypt.org/directory
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.email   # your email — Let's Encrypt sends expiry warnings here
        privateKeySecretRef = {
          # cert-manager stores the ACME account private key here
          # This key proves you own the Let's Encrypt account
          name = "letsencrypt-prod-account-key"
        }
        solvers = [{
          http01 = {
            ingress = {
              # HTTP-01 challenge: Let's Encrypt calls your domain on port 80
              # and checks a specific URL path for a token
              # nginx ingress handles this automatically
              class = "nginx"
            }
          }
        }]
      }
    }
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# NGINX INGRESS CONTROLLER
# Routes external traffic to services based on hostname
# Example: argocd.roboshop.com → argocd pods
#          vault.roboshop.com  → vault pods
# Gets a public Azure Load Balancer IP that DNS records point to
# ─────────────────────────────────────────────────────────────────────────────

resource "helm_release" "nginx_ingress" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.11.3"
  namespace  = kubernetes_namespace.ingress_nginx.metadata[0].name

  set {
    name  = "controller.replicaCount"
    value = "1"   # 1 for dev, 2+ for production
  }

  set {
    name  = "controller.nodeSelector.kubernetes\\.io/os"
    value = "linux"
  }

  # Azure-specific: health probe path
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-health-probe-request-path"
    value = "/healthz"
  }

  # This annotation ensures the load balancer is internal (private IP)
  # Comment this out if you want a public IP on nginx directly
  # For our setup: nginx has public IP, AGW also has public IP
  # We'll use nginx IP for tools, AGW IP for app
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-internal"
    value = "false"
  }

  wait    = true
  timeout = 300

  depends_on = [helm_release.cert_manager]
}

# ─────────────────────────────────────────────────────────────────────────────
# ARGOCD
# GitOps deployment engine
# Watches a Git repo and auto-deploys changes to Kubernetes
# This is HOW we will deploy RoboShop microservices — not kubectl, not helm CLI
# ─────────────────────────────────────────────────────────────────────────────

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "7.8.0"
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  # server.insecure=true because nginx terminates TLS
  # ArgoCD doesn't need its own TLS — nginx handles it
  set {
    name  = "configs.params.server\\.insecure"
    value = "true"
  }

  # Enable admin user (we'll add SSO later)
  set {
    name  = "configs.cm.admin\\.enabled"
    value = "true"
  }

  # Ingress for ArgoCD UI
  set {
    name  = "server.ingress.enabled"
    value = "true"
  }
  set {
    name  = "server.ingress.ingressClassName"
    value = "nginx"
  }
  set {
    name  = "server.ingress.hostname"
    value = "argocd.${var.domain}"
  }
  set {
    name  = "server.ingress.annotations.cert-manager\\.io/cluster-issuer"
    value = "letsencrypt-prod"
  }
  set {
    name  = "server.ingress.annotations.nginx\\.ingress\\.kubernetes\\.io/ssl-redirect"
    value = "true"
  }
  set {
    name  = "server.ingress.annotations.nginx\\.ingress\\.kubernetes\\.io/backend-protocol"
    value = "HTTP"
  }
  set {
    name  = "server.ingress.tls"
    value = "true"
  }

  # ApplicationSet controller — needed for deploying multiple services
  set {
    name  = "applicationSet.enabled"
    value = "true"
  }

  wait    = true
  timeout = 600

  depends_on = [helm_release.nginx_ingress]
}

# ─────────────────────────────────────────────────────────────────────────────
# VAULT
# HashiCorp Vault — secrets management
# All passwords for MongoDB, MySQL, RabbitMQ live here
# Pods authenticate using their K8s Service Account — no stored credentials
# ─────────────────────────────────────────────────────────────────────────────

resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  version    = "0.29.0"
  namespace  = kubernetes_namespace.vault.metadata[0].name

  # Single replica for dev
  set {
    name  = "server.replicas"
    value = "1"
  }

  # Disable TLS on Vault itself — nginx handles TLS
  set {
    name  = "global.tlsDisable"
    value = "true"
  }

  # Enable Vault Agent Injector
  # This is a mutating webhook — intercepts pod creation
  # Adds vault-agent sidecar container automatically based on annotations
  set {
    name  = "injector.enabled"
    value = "true"
  }

  # Standalone mode for dev (HA mode for prod uses Raft with 3 replicas)
  set {
    name  = "server.standalone.enabled"
    value = "true"
  }

  # Vault configuration — using heredoc in set
  set {
    name = "server.standalone.config"
    value = <<-EOT
      ui = true
      listener "tcp" {
        tls_disable = 1
        address = "[::]:8200"
        cluster_address = "[::]:8201"
      }
      storage "raft" {
        path = "/vault/data"
      }
      service_registration "kubernetes" {}
    EOT
  }

  # Storage for Vault data (persists secrets between pod restarts)
  set {
    name  = "server.dataStorage.enabled"
    value = "true"
  }
  set {
    name  = "server.dataStorage.size"
    value = "2Gi"
  }
  set {
    name  = "server.dataStorage.storageClass"
    value = "managed-csi"   # Azure managed disk
  }

  # Enable Vault UI
  set {
    name  = "ui.enabled"
    value = "true"
  }
  set {
    name  = "ui.serviceType"
    value = "ClusterIP"
  }

  # Vault ingress
  set {
    name  = "server.ingress.enabled"
    value = "true"
  }
  set {
    name  = "server.ingress.ingressClassName"
    value = "nginx"
  }
  set {
    name  = "server.ingress.hosts[0].host"
    value = "vault.${var.domain}"
  }
  set {
    name  = "server.ingress.hosts[0].paths[0]"
    value = "/"
  }
  set {
    name  = "server.ingress.annotations.cert-manager\\.io/cluster-issuer"
    value = "letsencrypt-prod"
  }
  set {
    name  = "server.ingress.annotations.nginx\\.ingress\\.kubernetes\\.io/ssl-redirect"
    value = "true"
  }
  set {
    name  = "server.ingress.tls[0].secretName"
    value = "vault-tls-cert"
  }
  set {
    name  = "server.ingress.tls[0].hosts[0]"
    value = "vault.${var.domain}"
  }

  wait    = true
  timeout = 600

  depends_on = [helm_release.nginx_ingress]
}

# ─────────────────────────────────────────────────────────────────────────────
# VAULT INITIALISATION
# After Vault pod starts, it is sealed and uninitialised
# We use a null_resource with a local-exec provisioner to:
# 1. Wait for Vault pod to be ready
# 2. Initialise Vault (generates root token + unseal keys)
# 3. Unseal Vault
# 4. Store root token and unseal key in Azure Key Vault
# All via shell script — no manual CLI needed
# ─────────────────────────────────────────────────────────────────────────────

resource "null_resource" "vault_init" {
  depends_on = [helm_release.vault]

  # Re-run if Vault helm release changes
  triggers = {
    vault_version = helm_release.vault.version
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e

      echo "Waiting for Vault pod to be Running..."
      kubectl wait --for=condition=Ready pod/vault-0 \
        -n vault \
        --timeout=300s

      echo "Checking if Vault is already initialised..."
      INIT_STATUS=$(kubectl exec -n vault vault-0 -- \
        vault status -format=json 2>/dev/null | jq -r '.initialized' || echo "false")

      if [ "$INIT_STATUS" = "true" ]; then
        echo "Vault already initialised — checking if sealed..."
        SEALED=$(kubectl exec -n vault vault-0 -- \
          vault status -format=json 2>/dev/null | jq -r '.sealed')

        if [ "$SEALED" = "true" ]; then
          echo "Vault is sealed — fetching unseal key from Azure Key Vault..."
          UNSEAL_KEY=$(az keyvault secret show \
            --vault-name "${var.azure_keyvault_name}" \
            --name "vault-unseal-key" \
            --query "value" -o tsv)
          kubectl exec -n vault vault-0 -- vault operator unseal "$UNSEAL_KEY"
          echo "Vault unsealed"
        else
          echo "Vault already running and unsealed"
        fi
        exit 0
      fi

      echo "Initialising Vault for the first time..."
      INIT_OUTPUT=$(kubectl exec -n vault vault-0 -- \
        vault operator init \
          -key-shares=1 \
          -key-threshold=1 \
          -format=json)

      UNSEAL_KEY=$(echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[0]')
      ROOT_TOKEN=$(echo "$INIT_OUTPUT" | jq -r '.root_token')

      echo "Saving keys to Azure Key Vault..."
      az keyvault secret set \
        --vault-name "${var.azure_keyvault_name}" \
        --name "vault-unseal-key" \
        --value "$UNSEAL_KEY" \
        --output none

      az keyvault secret set \
        --vault-name "${var.azure_keyvault_name}" \
        --name "vault-root-token" \
        --value "$ROOT_TOKEN" \
        --output none

      echo "Unsealing Vault..."
      kubectl exec -n vault vault-0 -- vault operator unseal "$UNSEAL_KEY"

      echo "Vault initialised and unsealed successfully"
      echo "Keys saved to Azure Key Vault: ${var.azure_keyvault_name}"
    EOT
  }
}

# Wait for Vault to be fully ready before configuring it
resource "time_sleep" "wait_for_vault" {
  depends_on      = [null_resource.vault_init]
  create_duration = "30s"
}

# ─────────────────────────────────────────────────────────────────────────────
# VAULT CONFIGURATION VIA TERRAFORM VAULT PROVIDER
# Everything below = vault CLI commands but in Terraform code
# No manual vault commands needed ever
# ─────────────────────────────────────────────────────────────────────────────

# Read root token from Azure Key Vault to use in Vault provider
data "azurerm_key_vault_secret" "vault_root_token" {
  name         = "vault-root-token"
  key_vault_id = var.azure_keyvault_id

  depends_on = [time_sleep.wait_for_vault]
}

# Enable KV v2 secrets engine at path "secret/"
# KV v2 = Key-Value version 2 = supports secret versioning
resource "vault_mount" "kv" {
  path        = "secret"
  type        = "kv"
  options     = { version = "2" }
  description = "KV v2 secrets engine for RoboShop"

  depends_on = [time_sleep.wait_for_vault]
}

# Enable Kubernetes auth method
# This is the bridge between K8s Service Accounts and Vault policies
resource "vault_auth_backend" "kubernetes" {
  type        = "kubernetes"
  description = "Kubernetes auth for AKS pods"

  depends_on = [vault_mount.kv]
}

# Configure Kubernetes auth — point Vault at the K8s API server
resource "vault_kubernetes_auth_backend_config" "config" {
  backend            = vault_auth_backend.kubernetes.path
  kubernetes_host    = "https://kubernetes.default.svc.cluster.local:443"
  # Running inside AKS, Vault can reach K8s API at this address
  # Vault uses its own service account to call K8s TokenReview API
  # to verify that incoming JWT tokens are valid

  depends_on = [vault_auth_backend.kubernetes]
}

# ── RoboShop Secrets ──────────────────────────────────────────────────────────
# All passwords stored here — never in code, never in K8s secrets, never in env vars

resource "vault_kv_secret_v2" "mongodb" {
  mount = vault_mount.kv.path
  name  = "roboshop/mongodb"

  data_json = jsonencode({
    username = "mongoadmin"
    password = var.mongodb_password
    # var.mongodb_password comes from terraform.tfvars
    # In real projects: comes from Azure Key Vault or env variable
    # NEVER hardcode passwords in .tf files — they end up in state
  })
}

resource "vault_kv_secret_v2" "mysql" {
  mount = vault_mount.kv.path
  name  = "roboshop/mysql"

  data_json = jsonencode({
    username = "shipping"
    password = var.mysql_password
    database = "cities"
    host     = "mysql.roboshop.svc.cluster.local"
    port     = "3306"
  })
}

resource "vault_kv_secret_v2" "rabbitmq" {
  mount = vault_mount.kv.path
  name  = "roboshop/rabbitmq"

  data_json = jsonencode({
    username = "roboshop"
    password = var.rabbitmq_password
    host     = "rabbitmq.roboshop.svc.cluster.local"
    port     = "5672"
  })
}

resource "vault_kv_secret_v2" "redis" {
  mount = vault_mount.kv.path
  name  = "roboshop/redis"

  data_json = jsonencode({
    host = "redis.roboshop.svc.cluster.local"
    port = "6379"
  })
}

resource "vault_kv_secret_v2" "payment" {
  mount = vault_mount.kv.path
  name  = "roboshop/payment"

  data_json = jsonencode({
    stripe_key = var.stripe_key
  })
}

# ── Vault Policy ──────────────────────────────────────────────────────────────
# Policy = what a role is allowed to read/write
# roboshop-policy = can ONLY read secrets under secret/data/roboshop/
# Cannot read other teams' secrets, cannot write anything

resource "vault_policy" "roboshop" {
  name = "roboshop-policy"

  policy = <<-EOT
    # Allow reading all RoboShop secrets
    path "secret/data/roboshop/*" {
      capabilities = ["read"]
    }

    # Allow pods to renew their own Vault token
    # Without this, tokens expire and pods lose secret access
    path "auth/token/renew-self" {
      capabilities = ["update"]
    }

    # Allow checking token validity
    path "auth/token/lookup-self" {
      capabilities = ["read"]
    }
  EOT
}

# ── Kubernetes Auth Role ──────────────────────────────────────────────────────
# This is the binding:
# "pods using service account 'roboshop-sa' in namespace 'roboshop'
#  are allowed to use 'roboshop-policy'"
# When a pod authenticates, Vault checks: does this SA + namespace match?
# If yes → issues a token with roboshop-policy attached

resource "vault_kubernetes_auth_backend_role" "roboshop" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "roboshop"
  bound_service_account_names      = ["roboshop-sa"]
  bound_service_account_namespaces = ["roboshop"]
  token_ttl                        = 86400   # 24 hours — agent auto-renews
  token_policies                   = [vault_policy.roboshop.name]

  depends_on = [
    vault_policy.roboshop,
    vault_kubernetes_auth_backend_config.config
  ]
}

# ── Kubernetes Service Account for RoboShop ───────────────────────────────────
# All RoboShop pods use this service account
# Vault agent uses this SA's JWT token to authenticate with Vault

resource "kubernetes_service_account" "roboshop" {
  metadata {
    name      = "roboshop-sa"
    namespace = kubernetes_namespace.roboshop.metadata[0].name
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# PROMETHEUS + GRAFANA
# kube-prometheus-stack installs everything in one chart:
# - Prometheus (scrapes metrics every 15s from all pods)
# - Grafana (dashboards — visualise metrics)
# - Alertmanager (sends alerts to Slack/email when things break)
# - node-exporter (node-level CPU/memory/disk metrics)
# - kube-state-metrics (K8s deployment/pod state metrics)
# ─────────────────────────────────────────────────────────────────────────────

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "68.1.0"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  # Grafana settings
  set {
    name  = "grafana.enabled"
    value = "true"
  }
  set {
    name  = "grafana.adminPassword"
    value = var.grafana_password
  }

  # Grafana ingress
  set {
    name  = "grafana.ingress.enabled"
    value = "true"
  }
  set {
    name  = "grafana.ingress.ingressClassName"
    value = "nginx"
  }
  set {
    name  = "grafana.ingress.hosts[0]"
    value = "grafana.${var.domain}"
  }
  set {
    name  = "grafana.ingress.annotations.cert-manager\\.io/cluster-issuer"
    value = "letsencrypt-prod"
  }
  set {
    name  = "grafana.ingress.tls[0].secretName"
    value = "grafana-tls"
  }
  set {
    name  = "grafana.ingress.tls[0].hosts[0]"
    value = "grafana.${var.domain}"
  }

  # Pre-install popular dashboards
  set {
    name  = "grafana.dashboardProviders.dashboardproviders\\.yaml.apiVersion"
    value = "1"
  }

  # Prometheus settings
  set {
    name  = "prometheus.enabled"
    value = "true"
  }
  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "3d"   # only keep 3 days to save disk in dev
  }
  set {
    name  = "prometheus.prometheusSpec.resources.requests.memory"
    value = "256Mi"
  }
  set {
    name  = "prometheus.prometheusSpec.resources.requests.cpu"
    value = "100m"
  }

  # AlertManager
  set {
    name  = "alertmanager.enabled"
    value = "true"
  }

  # Node exporter — collects metrics from each node
  set {
    name  = "nodeExporter.enabled"
    value = "true"
  }

  # Kube state metrics — collects K8s object state
  set {
    name  = "kubeStateMetrics.enabled"
    value = "true"
  }

  wait    = true
  timeout = 600

  depends_on = [helm_release.nginx_ingress]
}