#!/bin/bash

if ! [ -x "$(command -v az)" ] || ! [ -x "$(command -v terraform)" ] || ! [ -x "$(command -v terragrunt)" ] || ! [ -x "$(command -v git)" ]
then
  echo "You must have Azure Cli, Terraform, Terragrunt, and Git installed to use this utility";
  return;
fi

repoName=''
serviceName=''
ownerEmail=''
hasMigrations=false
repoType=''
complexity=''
collegiatelinkConnection=true
crossDomainMappings=false
team='Engage'
schema=''

az account show  >/dev/null 2>&1
status=$?

if [ "$status" != "0" ]
then
    az login --use-device-code --tenant 809fd6c8-b876-47a9-abe2-8be2888f4a55
fi

az account show  >/dev/null 2>&1
status=$?

if [ "$status" != "0" ]
then
    echo 'Unable to login to azure';
    return;
fi

promptQuestion() {
  local response;

  while true; do
    read -erp "$1: " response

    if [[ ! -z $response ]]; then
        break
    fi
  done
  echo "$response"
}

repoName=$(promptQuestion "Repo Name")
ownerEmail=$(promptQuestion "Owner Email")

read -p "Team [Engage]: " team
team=${team:-Engage}
read -p "Repo Type [Pillar]: " repoType
repoType=${repoType:-Pillar}
read -p "Complexity [Low]: " complexity
complexity=${complexity:-Low}
read -p "Has Collegiatelink Connection [true]: " collegiatelinkConnection
collegiatelinkConnection=${collegiatelinkConnection:-true}
read -p "Has Migrations [false]: " hasMigrations
hasMigrations=${hasMigrations:-false}
read -p "Has Cross Domain Mappings [false]: " crossDomainMappings
crossDomainMappings=${crossDomainMappings:-false}

serviceName=$(echo "$repoName" | sed -e 's/[^a-zA-Z]/-/g' -e 's/-{2,}/-/g' | awk '{print tolower($0)}')

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
  has_collegiatelink_connection: $collegiatelinkConnection 
  has_cross_domain_mappings: $crossDomainMappings
  team: Engage
---

# $repoName

Welcome.
EOF

touch build/ci.yml

cat <<"EOF" > build/ci.yml
name: $(Year:yyyy).$(Month).$(DayOfMonth)-beta$(Rev:r)

parameters:
  - name: onlySwapTest
    displayName: Only Swap Test
    type: boolean
    default: false

trigger:
  branches:
    include:
      - main
  paths:
    include:
      - src
      - test

pool:
  vmImage: ubuntu-latest

resources:
  repositories:
    - repository: self
    - repository: templates
      type: git
      name: Infra.PipelineTemplates

stages:
  - stage: Build
    condition: ne(${{ parameters.onlySwapTest }}, true)
    jobs:
      - job: Build
        steps:
          - template: shared/engage-ci-setup.yml@templates
          - template: netcore/restore.yml@templates
          - template: shared/snyk-scan.yml@templates
          - template: netcore/build.yml@templates
          - template: netcore/test.yml@templates
          - template: netcore/pack-contracts.yml@templates
          - template: netcore/publish-web.yml@templates            
          - template: shared/copy-artifacts.yml@templates
  - stage: Deploy
    dependsOn:
      - Build
    condition: and(succeeded(), ne(${{ parameters.onlySwapTest }}, true))
    jobs:
      - template: shared/deploy-slot-matrix.yml@templates
        parameters:
          azureSubscription: CollegiateLink Dev/Test
          environment: NonProd
          artifact: api
          package: '*.zip'
      - template: shared/deploy-slot-matrix.yml@templates
        parameters:
          azureSubscription: CollegiateLink Production
          environment: Prod
          artifact: api
          package: '*.zip'

  - stage: Swap
    dependsOn:
      - Deploy
    condition: or(eq(${{ parameters.onlySwapTest }}, true), and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main')))
    jobs:
      - template: shared/swap-slot-matrix.yml@templates
        parameters:
          azureSubscription: CollegiateLink Dev/Test
          environment: NonProd
          artifact: api
          healthCheckPath: /healthcheck
      - ${{ if ne(parameters.onlySwapTest, true) }}:
        - template: shared/swap-slot-matrix.yml@templates
          parameters:
            azureSubscription: CollegiateLink Production
            environment: Prod
            artifact: api
            healthCheckPath: /healthcheck

  - stage: Packages
    dependsOn:
      - Build
    condition: and(succeeded(), ne(${{ parameters.onlySwapTest }}, true))
    jobs:
      - template: nuget/push.yml@templates
EOF

if [ "$hasMigrations" = true ] ; then

read -p "Schema [dbo]: " schema
schema=${schema:-dbo}

mkdir -p lib/migrations/sql

touch build/migtations.yml

cat <<"EOF" > build/migtations.yml
name: $(Year:yyyy).$(Month).$(DayOfMonth).$(Rev:r)

trigger:
  branches:
    include:
      - main
  paths:
    include:
      - lib/migrations

pool:
  vmImage: ubuntu-latest

resources:
  repositories:
    - repository: self
    - repository: templates
      type: git
      name: Infra.PipelineTemplates

stages:
  - stage: Migrate
    jobs:
      - template: database/flyway-migrations.yml@templates
        parameters:
EOF

cat <<EOF >> build/migtations.yml
          sqlSchemas: $schema
EOF

touch lib/migrations/flyway.sh
cat <<"EOF" > lib/migrations/flyway.sh
#!/usr/bin/env zsh

command="$1"
if [[ -z "$command" ]]; then
  command="info"
fi

case "$2" in
  "olddev")
    server="azrdev"
    database="collegiatelink-dev"
    ;;
  "test")
    server="sql-se-infra-monolithdatabase-test-001"
    database="sqldb-se-infra-monolithdatabase-test-001"
    ;;
  "usa")
    server="collegiatelink"
    database="collegiatelink"
    ;;
  "can")
    server="collegiatelink-can"
    database="collegiatelink-can"
    ;;
  "sea")
    server="sql-se-infra-monolithdatabase-sea-001"
    database="sqldb-se-infra-monolithdatabase-sea-001"
    ;;
  *)
    server="sql-se-infra-monolithdatabase-dev-001"
    database="sqldb-se-infra-monolithdatabase-dev-001"
    isDev=1
    ;;
esac

flyway $command \
  -url="jdbc:sqlserver://$server.database.windows.net:1433;database=$database;encrypt=true" \
  -jdbcProperties.accessToken="$(az account get-access-token --resource https://database.windows.net/ --query accessToken --output tsv)" \
  -user="" \
  -password="" \
EOF

cat <<EOF >> lib/migrations/flyway.sh
  -schemas="$schema" \\
EOF

cat <<"EOF" >> lib/migrations/flyway.sh
  -table="FlywayMigrationHistory" \
  -placeholders.isDev=$isDev \
  -baselineVersion=0003
EOF
fi

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

pushd lib/terraform/live/non-prod/_global/devops
terragrunt apply
popd

git remote add origin https://dev.azure.com/campuslabs/CollegiateLink/_git/$repoName && \
git add . && \
git commit -m "Initial Commit" && \
git push origin main

echo "All Done!"
