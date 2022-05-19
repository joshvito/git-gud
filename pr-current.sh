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

az repos pr create --detect --auto-complete true --delete-source-branch true --description "$desc" --repository "$rep" --source-branch "$bn" --squash false --target-branch "$tb" --title "$tit" --output table --work-items "$wi"
