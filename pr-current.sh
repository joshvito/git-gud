#!/bin/bash

rep=$(basename "$(git rev-parse --show-toplevel)")
bn=$(git branch --show-current)
tit=''
desc=''
wi=''
useAc=''
ac=1        # 1 = true (auto-complete), 0 = false
draft=0     # 1 = true, 0 = false
optMode=0   # 1 = true, 0 = false
gitEditor=$(git config core.editor)
tb=$(git rev-parse --abbrev-ref origin/HEAD | cut -c8-)

############################################################
# Help                                                     #
############################################################
Help() {
  cat << EOF
Makes a pull request in Azure DevOps

Syntax: prcurrent [-t|d|n|r|m|h]

Options:
  -t <Title>             Set the Pull Request title.
  -d <Description>       Set the Pull Request description.
  -n <DevOps Ticket #>   Set the ticket number.
  -r                     Set the Pull Request to draft mode.
  -m                     Use manual complete mode (disable auto-complete).
  -h                     Show this help message.

EOF
}

############################################################
# Set PR Vars                                              #
############################################################
SetVars() {
  if [ -z "$tit" ]; then
    read -rp "PR Title: " tit
  fi

  if [ "$optMode" -eq 0 ] && [ -z "$desc" ]; then
    # Open editor to enter description
    tmpfile=$(mktemp /tmp/prdesc.XXXXXX)
    ${gitEditor:-vim} "$tmpfile"
    desc=$(<"$tmpfile")
    rm -f "$tmpfile"
  fi

  if [ -z "$wi" ]; then
    read -rp "Work Item Number(s): " wi
  fi

  if [ "$optMode" -eq 0 ] && [ -z "$useAc" ]; then
    read -rp "Use Auto Complete [Y]: " useAc
    useAc=${useAc:-Y}
    if [[ "$useAc" != "Y" && "$useAc" != "y" ]]; then
      ac=0
    fi
  fi
}
############################################################

OPTIND=1

# Parse short options with getopts
while getopts ":ht:d:n:mr" opt 
do
  optMode=1;
  case "$opt" in
    h) Help; return 1;;
    t) tit="$OPTARG";;
    d) desc="$OPTARG";;
    n) wi="$OPTARG";;
    m) ac=0;;
    r) draft=1;;
    \?) echo "Invalid option: -$OPTARG" >&2; return 1;;
  esac
done

SetVars

if [ -z "$desc" ]; then
  desc="$tit"
fi

echo "Checking account state..."
if ! az ad signed-in-user show >/dev/null 2>&1; then
  echo "Logging into Azure..."
  az login --use-device-code --tenant 809fd6c8-b876-47a9-abe2-8be2888f4a55
fi

if ! az ad signed-in-user show >/dev/null 2>&1; then
  echo "Unable to login to Azure"
  return 1
fi

if type jq &>/dev/null; then
    echo "Creating a PR.... hang on to your horses."
else
    echo "jq is not available and is required"
    return 1;
fi

ac_str="true"
if [ "$ac" -eq 0 ]; then
  ac_str="false"
fi

draft_str="false"
if [ "$draft" -eq 1 ]; then
  draft_str="true"
fi

pull_request=$(az repos pr create \
  --detect \
  --auto-complete "$ac_str" \
  --draft "$draft_str" \
  --delete-source-branch true \
  --description "$desc" \
  --repository "$rep" \
  --source-branch "$bn" \
  --squash true \
  --target-branch "$tb" \
  --title "$tit" \
  --output json \
  --work-items "$wi")

pull_request_id=$(echo "$pull_request" | jq -r '.pullRequestId')
url=$(echo "$pull_request" | jq -r '.repository.webUrl')
joined="$url/pullrequest/$pull_request_id"

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

echo "$joined"