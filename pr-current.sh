#!/bin/bash
rep=$(basename `git rev-parse --show-toplevel`)
bn=$(git branch --show-current)
r=''
read -p "PR Title: " tit
read -p "PR Description: " desc
read -p "Work Item Number(s): " wi
tb=$(git rev-parse --abbrev-ref origin/HEAD | cut -c8-)

az repos pr create --detect --auto-complete true --delete-source-branch true --description "$desc" --repository "$rep" --source-branch "$bn" --squash false --target-branch "$tb" --title "$tit" --output table --work-items wi
