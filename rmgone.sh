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

defaultBranch=$(git rev-parse --abbrev-ref origin/HEAD | cut -c8-)

git checkout $defaultBranch &>/dev/null
branches=$(git branch -vv | awk '/: gone]/{print $1}')

if [ -n "$branches" ]
then
    echo "Removing the following branches: " 
    echo $branches | tr ' ' '\n'
    git branch -vv | awk '/: gone]/{print $1}' | xargs git branch -D >> /dev/null 2>&1
fi

return 0;