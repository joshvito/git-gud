#!/bin/bash
rep=$(basename `git rev-parse --show-toplevel`)
bn=$(git branch --show-current)
tit=''
desc=''
wi=''
tb=$(git rev-parse --abbrev-ref origin/HEAD | cut -c8-)
OPTIND=1

while getopts ":t:d:n:" opt 
do
  case "$opt" in
    t) tit="$OPTARG";;
    d) desc="$OPTARG";;
    n) wi="$OPTARG";;
    \?) echo "Invalid option: -$OPTARG" >&2
        return 1;;
  esac
done

if [ -z "$tit" ]
then
	read -p "PR Title: " tit
fi

if [ -z "$desc" ]
then
	read -p "PR Description: " desc
fi

if [ -z "$wi" ]
then
	read -p "Work Item Number(s): " wi
fi

if [ -z "$desc" ]
then
	desc=$tit
fi

if type jq &>/dev/null; then
    echo "Creating a PR.... hang on to your horses."
else
    echo "jq is not available and is required"
    exit 0;
fi

pull_request=$(az repos pr create --detect --auto-complete true --delete-source-branch true --description "$desc" --repository "$rep" --source-branch "$bn" --squash true --target-branch "$tb" --title "$tit" --output json --work-items "$wi")

pull_request_id=$(echo $pull_request | jq -r '.pullRequestId');
url=$(echo $pull_request | jq -r '.repository.webUrl');

joined=$url/pullrequest/$pull_request_id
echo '-----------------------'
echo 'PR Created! You did it!'
echo '-----------------------'
echo $joined