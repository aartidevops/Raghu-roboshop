sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
sudo yum install -y terraform
terraform -version

# Install Azure CLI (RHEL 9)
# ---------------------------
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo curl -o /etc/yum.repos.d/azure-cli.repo https://packages.microsoft.com/config/rhel/9/prod.repo
sudo yum install -y azure-cli

az version

## ---------------------------
## Install kubectl (latest stable)
## ---------------------------
#KUBE_VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
#curl -LO "https://storage.googleapis.com/kubernetes-release/release/${KUBE_VERSION}/bin/linux/amd64/kubectl"
#
#chmod +x kubectl
#sudo mv kubectl /usr/local/bin/kubectl
#
## Fix PATH issue by symlinking into /usr/bin (which is already in PATH)
#if [ ! -f /usr/bin/kubectl ]; then
#  sudo ln -s /usr/local/bin/kubectl /usr/bin/kubectl
#fi
#
#kubectl version --client
