# git-gud
A collection of often used git related scripts

## Required programs
* Nodejs
* bash shell
* git
* az cli (pr-current.sh, repoizer.sh, pipelinerizer.sh, buildizer.sh)
* Terraform (repoizer.sh)
* Terragrunt (repoizer.sh)
* jq (pipelinerizer.sh, pr-current.sh, buildizer.sh) 

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
alias buildizer='bash ~/.util/buildizer.sh'
alias qb='bash ~/.util/buildizer.sh'
alias tpr='bash ~/.util/tpr.sh'
alias tprs='bash ~/.util/tprs.sh'
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
A bash script that searches the Engage project for pipelines by name and runs each of them against the `main` branch.
#### Requires:
* Azure Cli
* jq

### buildizer.sh
Queues the Azure DevOps pipeline for the repo you are standing in, against the branch you have checked out.
Org, project and repo come from `origin`'s URL, so it works in any ADO repo, not just Engage. Pipelines are
found by the repo they are attached to (`az pipelines list --repository`), not by name guessing. Refuses to
queue a branch that has not been pushed to `origin`. Aliased as both `buildizer` and `qb`.
```
qb          # pick from every pipeline attached to the repo
qb ci       # "<Repo> CI"
qb tf       # "<Repo> Terraform"
qb rele     # substring match on pipeline name
```
#### Optional Flags:
| Flag | Description |
| :------: | ----------- |
| -b | Queue this branch instead of the checked out one |
| -v | Pipeline variable `NAME=value`, repeatable |
| -n | Dry run - resolve and print, queue nothing |
| -o | Open the run in a browser |
| -y | No prompts; with no filter, queues every match |
#### Requires:
* Azure Cli
* jq

### tprs.sh
Lists every active pull request in an Azure DevOps project - all repos in one table, newest first.
Drafts are tagged `DRAFT`, which the ADO web list does not do. Org and project come from `origin` when
you are standing in a repo, otherwise they default to `encoura`/`engage`, so it also works from `~`.
`-t` hands the picked PR to `tpr`, which does the cd + fetch + open in `tuicr`.
The APPROVERS column holds the initials of everyone who has voted: bare initials approved, `!XX`
rejected, `~XX` waiting on the author. Reviewers who have not voted are left out, and the required
`ADO-Engage-Pull-Request-Reviewers` team is skipped - it is a policy, not a person. Blockers sort
first, and the column disappears when nothing in view has a vote.
CMTS is unresolved/total comment threads, counted the way tuicr counts them: deleted and
system-only threads (votes, policy, pushes) do not count, and fixed/closed/wontFix/byDesign
count as resolved. Threads are per-PR, so this is one request per PR listed - about 1.5s for ten.
It uses `AZURE_DEVOPS_EXT_PAT` (the PAT tuicr already wants); without one the column is skipped,
and `-N` turns it off. A cell reads `?` when that PR's request failed.
```
tprs              # every open PR in the project
tprs -m           # only mine
tprs -r           # only PRs waiting on my vote
tprs comp.        # substring on repo name or title
tprs -t           # pick a PR -> tuicr
tprs -t 2063      # straight to that PR
```
#### Optional Flags:
| Flag | Description |
| :------: | ----------- |
| -m | Only PRs I created |
| -r | Only PRs where I am a reviewer and have not voted |
| -c | Only PRs for the repo I am standing in |
| -D | Hide drafts |
| -N | Skip the comment counts |
| -u | Show the PR URL instead of the title |
| -R | Only this repo (substring) |
| -t | Open a PR in tuicr via `tpr`; takes an optional PR id |
#### Env:
| Variable | Description |
| :------: | ----------- |
| TPRS_ORG | Org, default: `origin`'s org, else `encoura` |
| TPRS_PROJECT | Project, default: `origin`'s project, else `engage` |
| TPRS_ME | Who `-m`/`-r` mean, default: `git config user.email` |
| TPRS_TOP | Max PRs to ask for, default 200 |
| TPRS_JSON | Read PR json from this file instead of calling az (testing) |
| AZURE_DEVOPS_EXT_PAT | Needed for the CMTS column (same PAT tuicr uses) |
#### Requires:
* Azure Cli
* jq
* fzf (optional - falls back to the `select` builtin)

### maintainerizer.js
A nodejs script that will read the passed in directory parameter (defaults to location of script execution) for any directories it contains. Then for each directory it turns on `git maintenance` via the `start` command;
