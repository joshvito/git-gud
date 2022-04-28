#!/bin/bash

if ! command -v git --version &> /dev/null
then
    echo "Error: git is not installed."
    exit
fi

if ! command git rev-parse --is-inside-work-tree &> /dev/null
then
	echo "Not in a git directory"
	exit
fi

defaultBranch=$(git rev-parse --abbrev-ref origin/HEAD | cut -c8-)

git checkout $defaultBranch &>/dev/null 
git branch -vv | awk '/: gone]/{print $1}' | xargs git branch -d i> /dev/null 2>&1

echo 'Removed branches with "gone" remote branches'
