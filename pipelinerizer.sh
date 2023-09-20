#!/bin/bash

tit=''
query=''
confirm=''
OPTIND=1

while getopts ":tq:" opt 
do
  case "$opt" in
    t) tit="$OPTARG";;
    q) query="$OPTARG";;
    \?) echo "Invalid option: -$OPTARG" >&2
        return 1;;
  esac
done

# Query overrides the search for a title so if we have a query, skip asking about a title
if [[ -z "$query" ]] && [ -z "$tit" ]
then
	read -p "Build pipline search term (case sensitive): [Terraform]" tit
    tit=${tit:-Terraform}
fi

# At this point we should have a query or a title, so lets set the query to be the title if we dont have a query
if [[ -z "$query" ]] && [ ! -z "$tit" ]
then
    query="[?contains(name, '${tit}')].name" 
fi

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
    exit;
fi

# Search for build pipelines with "terraform" in their name
pipeline_names=$(az pipelines build definition list --org "https://dev.azure.com/campuslabs/" --project "CollegiateLink" --query "$query" -o json)

# DEBUG
# echo $pipeline_names > output.json

echo We found the following pipelines to run.
echo $pipeline_names | jq -c '.[]' | while read i; do
    echo $i
done

read -p "Are you sure you want to run all of these piplines? [Y]: " confirm
confirm=${confirm:-Y}

if [ "${confirm}" != "Y" ] &&  [ "${confirm}" != "y" ]; then
    echo "Thanks for playing. Have a nice day."
    exit 0;
fi

# Iterate over the pipeline names and trigger them against the main branch
echo $pipeline_names | jq -rc '.[]' | while read i; do
    # echo "Triggering pipeline: $i"
    x=$(echo "$i"  | tr -d '\r')
    echo $x
    az pipelines build queue --definition-name "$x" --branch 'main' --org 'https://dev.azure.com/campuslabs/' --project 'CollegiateLink'
done