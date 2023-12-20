# git-gud
A collection of often used git related scripts

## Required programs
* Nodejs
* bash shell
* git
* az cli (pr-current.sh, repoizer.sh, pipelinerizer.sh)
* Terraform (repoizer.sh)
* Terragrunt (repoizer.sh)
* jq (pipelinerizer.sh, pr-current.sh) 

## Setup Instructions

`prunerizer.js` requires that `rmgone.sh` and `gbpurge.sh` have been aliased as commands in your `.bashrc` file. We put these alias here, so they can be called without a user profile (iirc: as the `.bash_profile` alias are not available via exec of child process and similar).

`~/.bashrc`

```
#!/bin/bash

alias gbpurge='source ~/.util/gbpurge.sh'
alias prcurrent='source ~/.util/pr-current.sh'
alias rmgone='source ~/.util/rmgone.sh'
alias repoizer='source ~/.util/repoizer.sh'
alias pipelinerizer='source ~/.util/pipelinerizer.sh'
```

Then in your `.bash_profile` file, you can add the `prunerizer script as an alias too.`
e.g.

`~/.bash_profile`
```
#!/bin/bash
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi

alias prunerize='node ~/.util/prunerizer ~/path/to/repos/for/prunering'

# list all your alias commands
aliases() {
	command alias | grep -one "^alias [a-z]*" | awk '{print $2}'
}
```

Then in your bash terminal, run `source ~/bash_profile`;

## Script Summaries

### prunerizer.js
A nodejs script that will read the passed in directory parameter for any directories it contains. Then for each directory it checks out the remote branch that is the HEAD target, pulls latest, prune the origin, and delete local branches that have been merged or gone (deleted remote);

### pr-current.sh
Uses az cli to create a PR for the currently selected branch in azure dev.azure.com. 
#### Optional Flags:
| Flag | Description |
| :------: | ----------- |
| -t | Sets the Title of the PR |
| -d | Sets the Description of the PR |
| -n | Sets the Work Item # of the PR |

### gbpurge.sh
Called from `prunerizer.js`, it will checkout the HEAD's branch, and delete any local branches that have been `[merged]`;

### rmgone.sh 
Called from `prunerizer.js`, it will checkout the HEAD's branch, and delete any local branches that are deleted, aka `[gone]`;

### repoizer.sh
A bash script for setting up new Engage repos. Follows the Student Engagement [Wiki document](https://dev.azure.com/campuslabs/Student%20Engagement/_wiki/wikis/Student-Engagement.wiki/1242/Repository-From-Scratch)
#### Requires:
* Terraform
* Terragrunt
* Azure Cli
* Git

### pipelinerizer.sh
A bash script that searches the Collegiatelink project for pipelines by name and runs each of them against the `main` branch.
#### Requires:
* Azure Cli
* jq