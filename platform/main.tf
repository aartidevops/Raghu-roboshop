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