# git-gud
A collection of often used git related scripts

## Required programs
* Nodejs
* az cli (pr-current.sh)
* bash shell
* git

## Setup Instructions

`prunerizer.js` requires that `rmgone.sh` and `gbpurge.sh` have been aliased as commands in your `.bashrc` file. We put these alias here, so they can be called without a user profile (iirc: as the `.bash_profile` alias are not available via exec of child process and similar).

`~/.bashrc`

```
#!/bin/bash

alias gbpurge='source ~/.util/gbpurge.sh'
alias prcurrent='source ~/.util/pr-current.sh'
alias rmgone='source ~/.util/rmgone.sh'
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
alias alias='alias | grep -one "^alias [a-z]*" | sed -e "s/alias //g"'
```

Then in your bash terminal, run `source ~/bash_profile`;

## Script Summaries

### prunerizer.js
A nodejs script that will read the passed in directory parameter, and checkout the trunk, prune the origin, and delete local branches that have been merged or gone(deleted remote);

### pr-current.sh
Uses az cli to create a PR for the currently selected branch in azure dev.azure.com. 

### gbpurge.sh
Called from `prunerizer.js`, it will checkout the HEAD's branch, and delete any local branches that have been `[merged]`;

### rmgone.sh 
Called from `prunerizer.js`, it will checkout the HEAD's branch, and delete any local branches that are deleted, aka `[gone]`;