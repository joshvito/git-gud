#!/bin/bash
rep=$(basename `git rev-parse --show-toplevel`)
bn=$(git branch --show-current)
tit=''
desc=''
wi=''
useAc=''
ac=true
draft=false
optMode=false
tb=$(git rev-parse --abbrev-ref origin/HEAD | cut -c8-)
OPTIND=1

############################################################
# Help                                                     #
############################################################
Help()
{
   # Display Help
   echo "Makes a pull request in Azure DevOps"
   echo
   echo "Syntax: prcurrent [-t|d|n|r|m|h]"
   echo "options:"
   echo "t  <Title>             Set the Pull Request title."
   echo "d  <Description>       Set the Pull Request description."
   echo "n  <DevOps Ticket #>   Set the ticket number."
   echo "r                      Set the Pull Request to use draft mode (Rough Draft)."
   echo "m                      Set the Pull Request to use manual Complete mode."
   echo "h                      Show this help message."
   echo
}

############################################################
# Set PR Vars                                              #
############################################################
SetVars()
{
  if [ -z "$tit" ]
  then
    read -p "PR Title: " tit
  fi

  if ( ! $optMode ) && [ -z "$desc" ]
  then
    read -p "PR Description: " desc
  fi

  if [ -z "$wi" ]
  then
    read -p "Work Item Number(s): " wi
  fi

  if ( ! $optMode ) && [ -z "$useAc" ]
  then
    read -p "Use Auto Complete [Y]: " useAc
    useAc=${useAc:-Y}
    
    if [ "$useAc" != "Y" ] && [ "$useAc" != "y" ]
    then
      ac=false
    fi
  fi
}

while getopts ":ht:d:n:m:r" opt 
do
  optMode=true;
  case "$opt" in
    h) Help 
      return 1;;
    t) tit="$OPTARG";;
    d) desc="$OPTARG";;
    n) wi="$OPTARG";;
    m) ac=false;;
    r) draft=true;;
    \?) echo "Invalid option: -$OPTARG" >&2
        return 1;;
  esac
done

SetVars

if [ -z "$desc" ]
then
	desc=$tit
fi

echo "Checking account state..."
az account show  >/dev/null 2>&1
status=$?

if [ "$status" != "0" ]
then
    echo "Logging into Azure..."
    az login --use-device-code --tenant 809fd6c8-b876-47a9-abe2-8be2888f4a55
fi

az account show  >/dev/null 2>&1
status=$?

if [ "$status" != "0" ]
then
    echo 'Unable to login to Azure';
    return;
fi

if type jq &>/dev/null; then
    echo "Creating a PR.... hang on to your horses."
else
    echo "jq is not available and is required"
    exit 0;
fi

pull_request=$(az repos pr create --detect --auto-complete $ac --draft $draft --delete-source-branch true --description "$desc" --repository "$rep" --source-branch "$bn" --squash true --target-branch "$tb" --title "$tit" --output json --work-items "$wi")

pull_request_id=$(echo $pull_request | jq -r '.pullRequestId');
url=$(echo $pull_request | jq -r '.repository.webUrl');
joined=$url/pullrequest/$pull_request_id

echo '----------------------------'
echo 'PR Created! This is the way'
echo '----------------------------'
echo '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⣀⣀⣀⣀⣀⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀'
echo '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣤⣴⣶⡿⠿⠿⠟⠛⠛⠛⠛⠛⠛⠿⠿⢿⣶⣶⣤⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀'
echo '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣴⣾⠿⠛⠋⢁⣀⣤⣤⣶⣶⣶⣶⣶⣶⣶⣶⣶⣦⣤⣄⣈⠉⠛⠿⣷⣦⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀'
echo '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣴⣾⠟⠋⣁⣤⣶⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣤⣀⠉⠻⢿⣦⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀'
echo '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣶⡿⠋⢀⣴⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⣄⠙⠻⣷⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀'
echo '⠀⠀⠀⠀⠀⠀⠀⠀⢀⣴⡿⠋⣠⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣄⠈⢻⣷⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀'
echo '⠀⠀⠀⠀⠀⠀⠀⣠⣿⠟⢀⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⡄⠙⣿⣆⠀⠀⠀⠀⠀⠀⠀⠀'
echo '⠀⠀⠀⠀⠀⠀⣰⣿⠃⢠⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠿⠿⠿⠿⠿⠿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣆⠈⢿⣧⡀⠀⠀⠀⠀⠀⠀'
echo '⡀⠂⠐⠒⠂⠐⠿⠁⢰⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠟⠋⠉⠀⠀⠀⠀⠤⠄⠀⠀⠀⠈⠉⠛⠿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣆⠈⢻⣷⠀⠀⠀⠀⠀⠀'
echo '⠀⠠⠀⠀⢤⣄⣀⠀⠀⠀⠀⠉⠉⠛⠛⠻⠿⠿⠟⠋⠁⠀⠀⠀⠀⠀⠀⠀⠤⠤⠤⠄⠀⠀⠀⠀⠀⠀⠀⠙⠻⢿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠧⠈⠿⠧⠀⠀⠤⠤⠄'
echo '⠀⠀⠀⢢⡀⢻⣿⣿⣿⣶⣶⣤⣄⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⡠⠀⢀⠌'
echo '⠀⠀⠀⢸⣷⠄⢻⣿⣿⣿⣿⣿⣿⣿⣿⣦⡀⠀⠀⠀⠠⠄⠒⠒⠠⠀⠀⠀⠀⠀⠀⠀⠀⢀⠄⠒⠀⠐⠢⠀⠀⠀⠀⠀⣠⣴⣶⣿⣿⣿⣿⣿⣿⣿⣿⠟⠀⠔⠁⠀'
echo '⠀⠀⠀⣼⡟⠐⡄⠻⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀⠀⢀⡔⠈⣿⣿⣶⣄⠀⠀⠀⠀⠀⠀⠀⢀⣴⠈⢻⣿⣶⣄⠀⠀⠀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⢃⣴⠁⠀⠀⠀'
echo '⠀⠀⠀⣿⡇⠀⣿⣦⡈⠻⢿⣿⣿⣿⣿⣿⡇⠀⠀⢺⣿⣾⣿⣿⣿⣿⡆⠀⠀⠀⠀⠀⠀⣿⣿⣷⣿⣾⣿⡿⠀⠀⢸⣿⣿⣿⣿⣿⣿⣿⣿⡿⢋⡀⢸⣿⡄⠀⠀⠀'
echo '⠀⠀⠀⣿⡇⠀⣿⣿⣿⣦⣄⡀⠀⠀⠈⠉⠃⠀⠀⠀⠈⠙⠛⠛⠛⠛⠁⠀⠐⠒⠒⠀⠀⠙⠛⠛⠛⠛⠉⠀⠀⠀⠘⠛⠛⠛⠛⠛⠛⣉⣥⣶⣿⡇⢸⣿⠀⠀⠀⠀'
echo '⠀⠀⠀⣿⣧⠀⣿⣿⣿⣿⣿⣿⣿⣶⣶⣤⡤⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠤⠀⠒⠂⠀⠄⠀⠀⠀⠀⠀⠀⠀⠀⢀⣤⣤⣤⣴⣶⣾⣿⣿⣿⣿⣿⠃⢸⣿⠀⠀⠀⠀'
echo '⠀⠀⠀⢹⣿⠀⢹⣿⣿⣿⣿⣿⣿⣿⣿⣿⣻⣿⣷⣦⣤⣤⣤⣤⣤⣤⡤⢤⣤⣤⣤⣴⣶⣶⣶⣶⣶⣶⣶⣶⣿⣿⣟⣿⠿⢿⣿⣿⣿⣿⣿⣿⣿⠀⣼⡿⠀⠀⠀⠀'
echo '⠀⠀⠀⠈⣿⣇⠈⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣻⣿⣿⣿⣿⣿⣿⡟⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠋⠀⠀⠴⣿⣿⣿⣿⣿⣿⠇⢠⣿⠇⠀⠀⠀⠀'
echo '⠀⠀⠀⠀⠸⣿⡄⠸⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⠛⢿⣿⣿⣿⣿⣷⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠿⠛⠋⢉⣿⣿⠁⠀⠀⠀⣀⣨⣿⣿⣿⣿⡟⠀⣾⡟⠀⠀⠀⠀⠀'
echo '⠀⠀⠀⠀⠀⠹⣷⡀⠹⣿⣿⣿⣿⣿⣿⣿⣿⡆⠀⠀⠀⠉⠙⢛⣻⣻⣿⣿⣿⡿⠿⠟⠛⠉⠀⠀⠀⠀⣼⣿⣿⢠⢤⣶⢺⣿⣿⣿⣿⣿⡟⠀⣼⡿⠀⠀⠀⠀⠀⠀'
echo '⠀⠀⠀⠀⠀⠀⠹⣷⡄⠙⣿⣿⣿⣿⣿⣿⣻⣿⣤⡀⠀⠀⠀⠈⠉⠉⣽⠉⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⣻⣿⣿⣷⣿⣿⣿⣿⣿⣿⣿⠏⢀⣾⡟⠁⠀⠀⠀⠀⠀⠀'
echo '⠀⠀⠀⠀⠀⠀⠀⠙⣿⣆⠈⠻⣿⣿⣿⣿⠃⠙⠿⣿⡶⠀⠀⠀⠀⠘⠽⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢻⣯⣿⣭⣿⣿⣿⣿⣿⡿⠃⣠⣾⠟⠀⠀⠀⠀⠀⠀⠀⠀'
echo '⠀⠀⠀⠀⠀⠀⠀⠀⠈⢻⣷⣄⠙⠿⣿⣿⣦⣾⣧⣬⠃⠀⠀⠀⠀⠀⡆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿⣿⣿⣿⣿⡿⠋⢀⣴⡿⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀'
echo '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⢿⣷⣄⠈⠻⢿⣿⣿⡟⠀⠀⠀⠀⠀⢀⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿⣿⣿⠟⠋⣠⣴⡿⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀'
echo '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠻⣿⣦⣄⠉⠛⠧⣄⡀⠀⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣨⡿⠟⠉⣀⣴⣾⠟⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀'
echo '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⠻⢿⣶⣤⣀⡉⠙⠓⠲⠾⠤⢤⣤⣤⣤⡤⠤⠤⠶⠒⠛⠉⣀⣤⣴⣿⠟⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀'
echo '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠛⠻⠿⣶⣶⣦⣤⣤⣤⣤⣤⣤⣤⣴⣶⣶⡿⠿⠛⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀'
echo '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠉⠉⠉⠉⠉⠉⠉⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀'

echo $joined
