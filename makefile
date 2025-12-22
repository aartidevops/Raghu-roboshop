dev-apply:
	git pull
	rm -f .terraform/terraform.tfstate
	terraform init -backend-config=./env-dev/state.tfvars
	terraform apply -auto-approve -var-file=env-dev/main.tfvars -var token=$(vault_token)