#!/bin/bash
set -e

echo "🔍 Detecting RHEL version..."
RHEL_VERSION=$(rpm -E '%{rhel}')
echo "➡️  RHEL version detected: $RHEL_VERSION"

# ---------------------------
# Install Terraform
# ---------------------------
echo "📦 Installing Terraform..."
dnf install -y yum-utils
dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
dnf install -y terraform
terraform -version

# ---------------------------
# Install Azure CLI (RHEL 9)
# ---------------------------
echo "📦 Installing Azure CLI..."
rpm --import https://packages.microsoft.com/keys/microsoft.asc
curl -o /etc/yum.repos.d/azure-cli.repo https://packages.microsoft.com/config/rhel/9/prod.repo
dnf install -y azure-cli
az version

# ---------------------------
# Install Ansible
# ---------------------------
echo "📦 Installing Ansible..."
if [ "$RHEL_VERSION" -eq 7 ]; then
    yum install -y epel-release
    yum install -y ansible
else
    dnf install -y ansible-core
fi

ansible --version


# ---------------------------
# Install kubectl (latest stable)
# ---------------------------
KUBE_VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
curl -LO "https://storage.googleapis.com/kubernetes-release/release/${KUBE_VERSION}/bin/linux/amd64/kubectl"

chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl

# Fix PATH issue by symlinking into /usr/bin (which is already in PATH)
if [ ! -f /usr/bin/kubectl ]; then
  sudo ln -s /usr/local/bin/kubectl /usr/bin/kubectl
fi

kubectl version --client

# ---------------------------
# Connect to AKS cluster
# ---------------------------
az login
az account set --subscription "0aa6e6f6-6e44-47f7-b30d-2aa0dfd4e5f4"

# ⚠️ Replace RG and NAME with actual values from `az aks list`
az aks get-credentials --resource-group RG --name aks

# ---------------------------
# Verify cluster connection
# ---------------------------
kubectl get nodes
kubectl get pods -A

# ---------------------------
# Install helm
# ---------------------------

#!/bin/bash
set -e

echo "🔍 Checking OS..."
if ! grep -qi "rhel" /etc/os-release; then
  echo "❌ This script is intended for RHEL systems only"
  exit 1
fi

echo "📦 Installing prerequisites..."
dnf install -y curl tar

echo "📦 Installing Helm (official method)..."
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "🔎 Verifying Helm installation..."
helm version --short

echo "✅ Helm installed successfully"


echo "✅ All tools installed successfully"
