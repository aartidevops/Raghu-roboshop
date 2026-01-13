    dev-apply:
	    git pull
	    terraform init -backend-config=./env-dev/state.tfvars
	    terraform apply -auto-approve -var-file=env-dev/main.tfvars


    dev-destroy:
	    git pull
	    terraform destroy -auto-approve -var-file=env-dev/main.tfvars