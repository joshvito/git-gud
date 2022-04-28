#!/bin/bash
if ! command -v git --version &> /dev/null
then
    echo "Error: git is not installed."
    return 0;
fi

if ! command git rev-parse --is-inside-work-tree &> /dev/null
then
    echo "Not in a git directory."
    return 0;
fi

rep=$(basename `git rev-parse --show-toplevel`)
tb=$(git rev-parse --abbrev-ref origin/HEAD | cut -c8-)

# replacement script for, since we had some trouble getting git rev-parse into a one line command
# alias gbpurge='git branch --merged | grep -v "\*" | grep -v "master" | grep -v "main" | xargs -rn 1 git branch -d'

echo Purging "$rep"
git checkout -l "$tb" &>/dev/null \n
git branch --merged | grep -v "\*" | grep -v "$tb" | xargs -rn 1 git branch -d
