#!/bin/bash
set -e

echo "🔍 Detecting RHEL version..."
RHEL_VERSION=$(rpm -E %{rhel})
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

echo "✅ All tools installed successfully"
