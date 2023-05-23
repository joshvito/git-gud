#!/bin/bash

tit=''
confirm=''
OPTIND=1

while getopts ":t:" opt 
do
  case "$opt" in
    t) tit="$OPTARG";;
    \?) echo "Invalid option: -$OPTARG" >&2
        return 1;;
  esac
done

if [ -z "$tit" ]
then
	read -p "Build pipline search term (case sensitive): [Terraform]" tit
    tit=${tit:-Terraform}
fi

# show current account
echo "Running builds as user: "
az account show

# Search for build pipelines with "terraform" in their name
pipeline_names=$(az pipelines build definition list --org "https://dev.azure.com/campuslabs/" --project "CollegiateLink" --query "[?contains(name, '$tit')].name" -o json)

echo We found the following pipelines to run.
echo $pipeline_names | jq -c '.[]'| while read i; do
    echo "$i"
done

read -p "Are you sure you want to run all of these piplines? [Y]: " confirm
confirm=${confirm:-Y}

if [ "${confirm^^}" != "Y" ]; then
    echo "Thanks for playing. Have a nice day."
    exit 0;
fi

# Iterate over the pipeline names and trigger them against the main branch
echo $pipeline_names | jq -c '.[]'| while read i; do
    echo "Triggering pipeline: $i"
    az pipelines build queue --definition-name "$name" --branch 'main'
done