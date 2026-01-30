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
# Install Azure CLI
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
# Install kubectl
# ---------------------------
echo "📦 Installing kubectl..."
KUBE_VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
curl -LO "https://storage.googleapis.com/kubernetes-release/release/${KUBE_VERSION}/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/kubectl

# Ensure kubectl is reachable
ln -sf /usr/local/bin/kubectl /usr/bin/kubectl
kubectl version --client

# ---------------------------
# Install Helm
# ---------------------------
echo "📦 Installing Helm..."
dnf install -y curl tar
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# ---------------------------
# FIX PATH ISSUE (IMPORTANT)
# ---------------------------
echo "🔧 Fixing PATH for /usr/local/bin..."

echo 'export PATH=$PATH:/usr/local/bin' | sudo tee /etc/profile.d/helm.sh
source /etc/profile
helm version


if ! echo "$PATH" | grep -q "/usr/local/bin"; then
  export PATH=$PATH:/usr/local/bin
  echo 'export PATH=$PATH:/usr/local/bin' >> /etc/profile
fi

# Optional but very safe
ln -sf /usr/local/bin/helm /usr/bin/helm

echo "🔎 Verifying Helm installation..."
helm version --short

# ---------------------------
# Connect to AKS
# ---------------------------
az login
az account set --subscription "0aa6e6f6-6e44-47f7-b30d-2aa0dfd4e5f4"
az aks get-credentials --resource-group RG --name aks

echo "📦 Creating roboshop namespace..."
kubectl create namespace roboshop --dry-run=client -o yaml | kubectl apply -f -


# ---------------------------
# Verify cluster
# ---------------------------
kubectl get nodes
kubectl get pods -A

echo "✅ All tools installed successfully"
