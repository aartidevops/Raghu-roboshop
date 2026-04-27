# ─────────────────────────────────────────────────────────────────────────────
# NAMESPACES
# Create all namespaces before installing anything into them
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
      "vault.io/enabled" = "true"
    }
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# CERT-MANAGER
# Issues free TLS certs from Let's Encrypt
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
  }

  wait             = true
  wait_for_jobs    = true
  timeout          = 300
  cleanup_on_fail  = true
}

# Wait for cert-manager webhooks to be ready before creating ClusterIssuer
# Without this wait, kubectl apply for ClusterIssuer fails because
# the validating webhook isn't ready yet
resource "time_sleep" "wait_for_cert_manager" {
  depends_on      = [helm_release.cert_manager]
  create_duration = "30s"
}

# ClusterIssuer — Let's Encrypt config
# Using kubectl provider (gavinbunney/kubectl) because it handles
# CRD-based resources better than kubernetes_manifest during first apply
resource "kubectl_manifest" "cluster_issuer" {
  depends_on = [time_sleep.wait_for_cert_manager]

  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-prod
    spec:
      acme:
        server: https://acme-v02.api.letsencrypt.org/directory
        email: ${var.email}
        privateKeySecretRef:
          name: letsencrypt-prod-account-key
        solvers:
          - http01:
              ingress:
                class: nginx
  YAML
}

# ─────────────────────────────────────────────────────────────────────────────
# NGINX INGRESS CONTROLLER
# Gets a public Azure LB IP — DNS A records point to this IP
# Routes traffic to services by hostname
# ─────────────────────────────────────────────────────────────────────────────

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

  # Azure LB health probe — Azure requires this to mark LB as healthy
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-health-probe-request-path"
    value = "/healthz"
  }

  # Resource limits — important for B4ms nodes
  set {
    name  = "controller.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "controller.resources.requests.memory"
    value = "128Mi"
  }

  wait            = true
  timeout         = 300
  cleanup_on_fail = true

  depends_on = [helm_release.cert_manager]
}

# Wait for nginx to get its external IP before creating ingresses
resource "time_sleep" "wait_for_nginx" {
  depends_on      = [helm_release.nginx_ingress]
  create_duration = "60s"
  # Azure takes ~60s to assign the public IP to the LoadBalancer service
}

# ─────────────────────────────────────────────────────────────────────────────
# ARGOCD
# GitOps engine — deploys RoboShop from Git automatically
# Access: https://argocd.skilltechnology.online
# ─────────────────────────────────────────────────────────────────────────────

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "7.8.0"
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  # ArgoCD runs in insecure mode because nginx handles TLS
  set {
    name  = "configs.params.server\\.insecure"
    value = "true"
  }

  set {
    name  = "configs.cm.admin\\.enabled"
    value = "true"
  }

  # Ingress — ArgoCD UI accessible at argocd.skilltechnology.online
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

  # Reduce resource usage for dev
  set {
    name  = "server.resources.requests.cpu"
    value = "50m"
  }

  set {
    name  = "server.resources.requests.memory"
    value = "128Mi"
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
    name  = "applicationSet.enabled"
    value = "true"
  }

  wait            = true
  timeout         = 600
  cleanup_on_fail = true

  depends_on = [time_sleep.wait_for_nginx]
}

# ─────────────────────────────────────────────────────────────────────────────
# VAULT
# Secrets management — all passwords live here
# Pods authenticate using K8s Service Account JWT — no stored passwords
# Access: https://vault.skilltechnology.online
# ─────────────────────────────────────────────────────────────────────────────

resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  version    = "0.29.0"
  namespace  = kubernetes_namespace.vault.metadata[0].name

  set {
    name  = "global.tlsDisable"
    value = "true"
  }

  # Vault Agent Injector
  # This mutating webhook auto-adds vault-agent sidecar to pods with vault annotations
  set {
    name  = "injector.enabled"
    value = "true"
  }

  set {
    name  = "server.standalone.enabled"
    value = "true"
  }

  # Vault config as HCL
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
    value = "vault-tls"
  }

  set {
    name  = "server.ingress.tls[0].hosts[0]"
    value = "vault.${var.domain}"
  }

  set {
    name  = "server.resources.requests.cpu"
    value = "50m"
  }

  set {
    name  = "server.resources.requests.memory"
    value = "128Mi"
  }

  wait            = true
  timeout         = 600
  cleanup_on_fail = true

  depends_on = [time_sleep.wait_for_nginx]
}

# ─────────────────────────────────────────────────────────────────────────────
# PROMETHEUS + GRAFANA
# Metrics and dashboards
# Access: https://grafana.skilltechnology.online
# ─────────────────────────────────────────────────────────────────────────────

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "68.1.0"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

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

  set {
    name  = "grafana.resources.requests.cpu"
    value = "50m"
  }

  set {
    name  = "grafana.resources.requests.memory"
    value = "128Mi"
  }

  set {
    name  = "prometheus.enabled"
    value = "true"
  }

  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "2d"
  }

  set {
    name  = "prometheus.prometheusSpec.resources.requests.memory"
    value = "256Mi"
  }

  set {
    name  = "prometheus.prometheusSpec.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "alertmanager.enabled"
    value = "false"  # disable for dev — saves resources
  }

  set {
    name  = "nodeExporter.enabled"
    value = "true"
  }

  set {
    name  = "kubeStateMetrics.enabled"
    value = "true"
  }

  # Disable some heavy components for dev
  set {
    name  = "defaultRules.create"
    value = "true"
  }

  wait            = true
  timeout         = 600
  cleanup_on_fail = true

  depends_on = [time_sleep.wait_for_nginx]
}

# ─────────────────────────────────────────────────────────────────────────────
# ROBOSHOP NAMESPACE SERVICE ACCOUNT
# All RoboShop pods use this SA to authenticate with Vault
# ─────────────────────────────────────────────────────────────────────────────

resource "kubernetes_service_account" "roboshop" {
  metadata {
    name      = "roboshop-sa"
    namespace = kubernetes_namespace.roboshop.metadata[0].name
  }

  depends_on = [kubernetes_namespace.roboshop]
}