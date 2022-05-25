#!/bin/bash

repoName=''
serviceName=''
ownerEmail=''
hasMigrations=false
repoType='Pillar'
complexity='Low'

read -p "Repo Name: " repoName
read -p "Owner Email: " ownerEmail

serviceName=$(echo "$repoName" | sed -e 's/[^a-zA-Z]/-/g' -e 's/-{2,}/-/g' -e 's/\(.*\)/\L\1/')

mkdir $repoName
cd $repoName

curl -o .gitignore https://www.toptal.com/developers/gitignore/api/vscode,intellij,rider,windows,osx,dotnetcore,terraform,terragrunt,visualstudio

echo >> .gitignore
echo ".terraform.lock.hcl" >> .gitignore

git init -b main
git add .gitignore
git commit -m "Add a gitignore."

mkdir -p build
mkdir -p lib/terraform/live/non-prod/_global/devops

touch README.md

cat <<EOF > README.md
---
service_name: $serviceName
owner_email_addresses:
  - $ownerEmail
project_details:
  repo_name: $repoName
  has_migrations: $hasMigrations
  type: $repoType
  complexity: $complexity
  is_legacy: false
---

# $repoName

Welcome.
EOF

touch build/terraform.yml

cat <<"EOF" > build/terraform.yml
name: $(Year:yyyy).$(Month).$(DayOfMonth).$(Rev:r)

trigger:
  branches:
    include:
      - main
  paths:
    include:
      - lib/terraform

pool:
  vmImage: ubuntu-latest

resources:
  repositories:
    - repository: self
    - repository: templates
      type: git
      name: Infra.PipelineTemplates

stages:
  - stage: Terraform
    jobs:
      - template: terraform/terragrunt-all.yml@templates
        parameters:
          azureSubscription: CollegiateLink Dev/Test Terraform
          azureSubscriptionType: NonProd
          terragruntWorkingDirectory: live/non-prod
      - template: terraform/terragrunt-all.yml@templates
        parameters:
          azureSubscription: CollegiateLink Production Terraform
          azureSubscriptionType: Prod
          terragruntWorkingDirectory: live/prod
EOF

touch lib/terraform/live/root.hcl

cat <<"EOF" > lib/terraform/live/root.hcl
locals {
  global_inputs = merge(
    { business_unit = "se" },
    yamldecode(trim(regex("---(?s:.+)---", file(find_in_parent_folders("README.md"))), "---"))
  )
  account_hcl = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env_hcl     = try(read_terragrunt_config(find_in_parent_folders("env.hcl")), {})
  region_hcl  = try(read_terragrunt_config(find_in_parent_folders("region.hcl")), {})
}

remote_state {
  backend = "azurerm"
  config = {
    resource_group_name  = local.account_hcl.locals.tfstate_resource_group_name
    storage_account_name = local.account_hcl.locals.tfstate_storage_account_name
    container_name       = local.account_hcl.locals.tfstate_container_name
    key                  = format("%s/%s/terraform.tfstate", lower(local.global_inputs.project_details.repo_name), path_relative_to_include())
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

inputs = merge(
  local.global_inputs,
  coalesce(local.account_hcl.inputs, {}),
  try(local.env_hcl.inputs, {}),
  try(local.region_hcl.inputs, {}),
)
EOF

touch lib/terraform/live/non-prod/account.hcl

cat <<"EOF" > lib/terraform/live/non-prod/account.hcl
locals {
  tfstate_resource_group_name  = "rg-se-terraform-test-001"
  tfstate_storage_account_name = "stseterraformtest001"
  tfstate_container_name       = "tfstate"
}
EOF

touch lib/terraform/live/non-prod/_global/devops/terragrunt.hcl

cat <<"EOF" > lib/terraform/live/non-prod/_global/devops/terragrunt.hcl
terraform {
  source = "git::https://campuslabs@dev.azure.com/campuslabs/Student%20Engagement%20Terraform/_git/azuredevops_engage_repository//?ref=main"
}

include {
  path = find_in_parent_folders("root.hcl")
}
EOF

#pushd lib/terraform/live/non-prod/_global/devops
#terragrunt apply
#popd

cat << EOF
Once the devops Module has been applied, commit all your changes.
Then you can open up your new Repository in Azure DevOps and grab the commands from the "Push an existing repository from command line".
Run those commands and then your code should all be in Azure DevOps ready to go!

Now you can start Terraforming your infrastructure!
EOF