#!/bin/bash
rep=$(basename `git rev-parse --show-toplevel`)
tb=$(git rev-parse --abbrev-ref origin/HEAD | cut -c8-)

# replacement script for, since we had some trouble getting git rev-parse into a one line command
# alias gbpurge='git branch --merged | grep -v "\*" | grep -v "master" | grep -v "main" | xargs -rn 1 git branch -d'

echo Purging "$rep"
git checkout -l "$tb" &>/dev/null \n
git branch --merged | grep -v "\*" | grep -v "$tb" | xargs -rn 1 git branch -d
