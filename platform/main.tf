# ═══════════════════════════════════════════════════════════════
# TOOL 1 — cert-manager
#
# What it does:
#   Automatically issues and renews free TLS certificates
#   from Let's Encrypt. Without this, browsers show "Not Secure"
#   on all our tools. With this, HTTPS works everywhere and
#   certificates auto-renew every 90 days — zero manual work.
#
# What it creates in Kubernetes:
#   - 3 pods: cert-manager, cert-manager-cainjector, cert-manager-webhook
#   - New resource types (CRDs): Certificate, ClusterIssuer, CertificateRequest
#   - ClusterIssuer: tells cert-manager to use Let's Encrypt
#
# How it fits the bigger picture:
#   nginx ingress (next tool) will reference letsencrypt-prod
#   ClusterIssuer when creating ingress rules. cert-manager
#   intercepts that and issues the cert automatically.
# ═══════════════════════════════════════════════════════════════

# Namespace: cert-manager
resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
  }
}

# Install cert-manager via Helm
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
    # These are new "kinds" of objects cert-manager adds to Kubernetes:
    #   Certificate, ClusterIssuer, CertificateRequest, Order, Challenge
    # Without crds.enabled=true the Helm chart installs
    # but nothing actually works — most common mistake
  }

  set {
    name  = "global.leaderElection.namespace"
    value = "cert-manager"
  }

  # Low resource requests for dev — B4ms nodes have limited RAM
  set {
    name  = "resources.requests.cpu"
    value = "50m"
  }
  set {
    name  = "resources.requests.memory"
    value = "64Mi"
  }

  # wait=true means Terraform waits until all cert-manager pods
  # are Running before continuing to next resource
  # Without this: ClusterIssuer below would apply before webhook
  # is ready and fail with "connection refused"
  wait          = true
  wait_for_jobs = true
  timeout       = 300

  depends_on = [kubernetes_namespace.cert_manager]
}

# Wait 30 seconds after cert-manager installs
# Reason: cert-manager registers a validating webhook with Kubernetes
# The webhook validates ClusterIssuer objects before they're stored
# If we apply ClusterIssuer too fast, webhook isn't ready → error
# 30 seconds gives the webhook time to fully register
resource "time_sleep" "wait_for_cert_manager_webhook" {
  depends_on      = [helm_release.cert_manager]
  create_duration = "30s"
}

# ClusterIssuer — tells cert-manager WHERE to get certificates
#
# ClusterIssuer is cluster-scoped (works in ALL namespaces)
# Issuer is namespace-scoped (only works in one namespace)
# Real projects always use ClusterIssuer — one config for everything
#
# We use kubectl_manifest here (not kubernetes_manifest) because:
# - kubernetes_manifest validates the CRD schema at plan time
# - If AKS was just created, the ClusterIssuer CRD doesn't exist yet
# - Plan fails with "no matches for kind ClusterIssuer"
# - kubectl_manifest applies raw YAML without schema validation
# - Works on first apply, works on every subsequent apply
resource "kubectl_manifest" "cluster_issuer" {
  depends_on = [time_sleep.wait_for_cert_manager_webhook]

  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-prod
    spec:
      acme:
        # Let's Encrypt production server
        # Free, trusted by all browsers
        # Rate limit: 50 certificates per domain per week
        # Use staging for testing: https://acme-staging-v02.api.letsencrypt.org/directory
        server: https://acme-v02.api.letsencrypt.org/directory
        email: ${var.email}
        privateKeySecretRef:
          # cert-manager stores your Let's Encrypt account key here
          # Survives pod restarts — kept in Kubernetes secret
          name: letsencrypt-prod-account-key
        solvers:
          - http01:
              ingress:
                class: nginx
                # HTTP-01 challenge — how Let's Encrypt verifies you own the domain:
                # 1. You request cert for vault.skilltechnology.online
                # 2. LE says: serve a token at /.well-known/acme-challenge/TOKEN
                # 3. cert-manager creates a temporary ingress rule in nginx
                # 4. LE fetches http://vault.skilltechnology.online/.well-known/...
                # 5. Token matches → LE issues the certificate
                # This is why nginx must exist before certificates can be issued
  YAML
}


# ═══════════════════════════════════════════════════════════════
# TOOL 2 — nginx ingress controller
#
# What it does:
#   Gets a public Azure Load Balancer IP.
#   Routes traffic to the right pod based on hostname.
#   Example: vault.skilltechnology.online → vault pod
#
# Why before Vault:
#   Vault needs an ingress rule to be reachable by DNS.
#   That ingress rule needs nginx to exist first.
# ═══════════════════════════════════════════════════════════════

resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = "ingress-nginx"
  }
}

resource "helm_release" "nginx_ingress" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.11.3"
  namespace  = kubernetes_namespace.ingress_nginx.metadata[0].name

  set {
    name  = "controller.replicaCount"
    value = "1"
  }

  set {
    name  = "controller.nodeSelector.kubernetes\\.io/os"
    value = "linux"
  }

  # Azure needs this annotation or LB health probe fails
  # Without it: LB marks nginx as unhealthy → no traffic flows
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-health-probe-request-path"
    value = "/healthz"
  }

  set {
    name  = "controller.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "controller.resources.requests.memory"
    value = "128Mi"
  }

  wait    = true
  timeout = 300

  depends_on = [
    kubernetes_namespace.ingress_nginx,
    helm_release.cert_manager
  ]
}


# ═══════════════════════════════════════════════════════════════
# TOOL 3 — HashiCorp Vault
# Stores all secrets. Pods get secrets via sidecar injection.
# Accessible at: https://vault.skilltechnology.online
# ═══════════════════════════════════════════════════════════════

resource "kubernetes_namespace" "vault" {
  metadata {
    name = "vault"
  }
}

resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  version    = "0.29.0"
  namespace  = kubernetes_namespace.vault.metadata[0].name

  set {
    name  = "global.tlsDisable"
    value = "true"
    # nginx handles TLS — vault doesn't need to
  }

  set {
    name  = "injector.enabled"
    value = "true"
    # sidecar injector — auto-injects vault-agent into app pods
  }

  set {
    name  = "injector.resources.requests.cpu"
    value = "50m"
  }

  set {
    name  = "injector.resources.requests.memory"
    value = "64Mi"
  }


  # Standalone vs HA — controlled by var.vault_replicas
  set {
    name  = "server.standalone.enabled"
    value = var.vault_replicas == 1 ? "true" : "false"
  }

  set {
    name  = "server.ha.enabled"
    value = var.vault_replicas > 1 ? "true" : "false"
  }

  set {
    name  = "server.ha.replicas"
    value = tostring(var.vault_replicas)
  }

  set {
    name  = "server.ha.raft.enabled"
    value = var.vault_replicas > 1 ? "true" : "false"
  }

  set {
    name  = "server.standalone.config"
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
    value = "managed-csi"
  }

  set {
    name  = "server.resources.requests.cpu"
    value = "50m"
  }

  set {
    name  = "server.resources.requests.memory"
    value = "128Mi"
  }

  set {
    name  = "ui.enabled"
    value = "true"
  }

  set {
    name  = "ui.serviceType"
    value = "ClusterIP"
  }

  # Ingress — exposes Vault UI at vault.skilltechnology.online
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
    value = "\"true\""
  }

  set {
    name  = "server.ingress.tls[0].secretName"
    value = "vault-tls"
  }

  set {
    name  = "server.ingress.tls[0].hosts[0]"
    value = "vault.${var.domain}"
  }

  wait    = true
  timeout = 600

  depends_on = [
    kubernetes_namespace.vault,
    helm_release.nginx_ingress,
    kubectl_manifest.cluster_issuer
  ]
}


# ═══════════════════════════════════════════════════════════════
# TOOL 4 — ArgoCD
#
# GitOps engine. Watches a Git repo and auto-deploys changes.
# One ArgoCD manages ALL environments (dev/uat/prod) using
# separate namespaces and separate Application manifests.
#
# Accessible at: https://argocd.skilltechnology.online
# ═══════════════════════════════════════════════════════════════

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "7.8.0"
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  # ArgoCD runs in insecure mode — nginx handles TLS
  set {
    name  = "configs.params.server\\.insecure"
    value = "true"
  }

  set {
    name  = "configs.cm.admin\\.enabled"
    value = "true"
  }

  # HA mode toggle — false=1 replica, true=3 replicas
  # Change var.argocd_ha_enabled=true for prod HA
  set {
    name  = "server.replicas"
    value = var.argocd_ha_enabled ? "3" : "1"
  }

  set {
    name  = "repoServer.replicas"
    value = var.argocd_ha_enabled ? "3" : "1"
  }

  set {
    name  = "applicationSet.replicas"
    value = var.argocd_ha_enabled ? "3" : "1"
  }

  # Ingress
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
    value = "\"true\""
  }

  set {
    name  = "server.ingress.annotations.nginx\\.ingress\\.kubernetes\\.io/backend-protocol"
    value = "HTTP"
  }

  set {
    name  = "server.ingress.tls"
    value = "true"
  }

  # Resource limits — scale up for prod
  set {
    name  = "server.resources.requests.cpu"
    value = var.environment == "prod" ? "100m" : "50m"
  }

  set {
    name  = "server.resources.requests.memory"
    value = var.environment == "prod" ? "256Mi" : "128Mi"
  }

  set {
    name  = "repoServer.resources.requests.cpu"
    value = "50m"
  }

  set {
    name  = "repoServer.resources.requests.memory"
    value = "128Mi"
  }

  set {
    name  = "redis.resources.requests.cpu"
    value = "50m"
  }

  set {
    name  = "redis.resources.requests.memory"
    value = "64Mi"
  }

  # ApplicationSet — needed for multi-env deployment patterns
  set {
    name  = "applicationSet.enabled"
    value = "true"
  }

  wait    = true
  timeout = 600

  depends_on = [
    kubernetes_namespace.argocd,
    helm_release.nginx_ingress,
    kubectl_manifest.cluster_issuer
  ]
}

# ── App namespaces ──────────────────────────────────────────────
# One namespace per environment
# ArgoCD deploys into these namespaces
# Vault policies are scoped to these namespaces
# This is the environment isolation boundary

resource "kubernetes_namespace" "roboshop_dev" {
  metadata {
    name = "roboshop-dev"
    labels = {
      environment = "dev"
      app         = "roboshop"
    }
  }
}

resource "kubernetes_namespace" "roboshop_uat" {
  metadata {
    name = "roboshop-uat"
    labels = {
      environment = "uat"
      app         = "roboshop"
    }
  }
}

resource "kubernetes_namespace" "roboshop_prod" {
  metadata {
    name = "roboshop-prod"
    labels = {
      environment = "prod"
      app         = "roboshop"
    }
  }
}

# ── Service accounts per environment ───────────────────────────
# Vault K8s auth is bound to these service accounts
# Pod must use this SA to get secrets from Vault
# Each env has its own SA → own policy → own secrets

resource "kubernetes_service_account" "roboshop_dev" {
  metadata {
    name      = "roboshop-sa"
    namespace = kubernetes_namespace.roboshop_dev.metadata[0].name
  }
}

resource "kubernetes_service_account" "roboshop_uat" {
  metadata {
    name      = "roboshop-sa"
    namespace = kubernetes_namespace.roboshop_uat.metadata[0].name
  }
}

resource "kubernetes_service_account" "roboshop_prod" {
  metadata {
    name      = "roboshop-sa"
    namespace = kubernetes_namespace.roboshop_prod.metadata[0].name
  }
}

# ── ArgoCD RBAC ConfigMap ──────────────────────────────────────
# Controls who can do what in ArgoCD
# dev team: can sync dev only
# uat team: can sync dev + uat
# ops team: can sync everything including prod

resource "kubernetes_config_map" "argocd_rbac" {
  metadata {
    name      = "argocd-rbac-cm"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }

  data = {
    "policy.csv" = <<-EOT
      # Developers — view all, sync dev only
      p, role:developer, applications, get,  */*, allow
      p, role:developer, applications, sync, roboshop-dev/*, allow

      # UAT team — view all, sync dev + uat
      p, role:uat-team, applications, get,  */*, allow
      p, role:uat-team, applications, sync, roboshop-dev/*, allow
      p, role:uat-team, applications, sync, roboshop-uat/*, allow

      # Ops — full access
      p, role:ops, applications, *, */*, allow
      p, role:ops, clusters,      *, */*, allow

    EOT
    "policy.default" = "role:readonly"
  }

  depends_on = [helm_release.argocd]
}

# ── ArgoCD Projects per environment ────────────────────────────
# AppProject restricts what ArgoCD can deploy and where
# Prevents dev project from deploying to prod namespace

resource "kubectl_manifest" "argocd_project_dev" {
  depends_on = [helm_release.argocd]

  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: AppProject
    metadata:
      name: roboshop-dev
      namespace: argocd
    spec:
      description: RoboShop dev environment
      sourceRepos:
        - '*'
      destinations:
        - namespace: roboshop-dev
          server: https://kubernetes.default.svc
      clusterResourceWhitelist:
        - group: ''
          kind: Namespace
  YAML
}

resource "kubectl_manifest" "argocd_project_uat" {
  depends_on = [helm_release.argocd]

  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: AppProject
    metadata:
      name: roboshop-uat
      namespace: argocd
    spec:
      description: RoboShop UAT environment
      sourceRepos:
        - '*'
      destinations:
        - namespace: roboshop-uat
          server: https://kubernetes.default.svc
      clusterResourceWhitelist:
        - group: ''
          kind: Namespace
  YAML
}

resource "kubectl_manifest" "argocd_project_prod" {
  depends_on = [helm_release.argocd]

  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: AppProject
    metadata:
      name: roboshop-prod
      namespace: argocd
    spec:
      description: RoboShop production environment
      sourceRepos:
        - '*'
      destinations:
        - namespace: roboshop-prod
          server: https://kubernetes.default.svc
      clusterResourceWhitelist:
        - group: ''
          kind: Namespace
  YAML
}