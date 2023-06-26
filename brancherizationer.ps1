$projectName = "collegiatelink"

# set default organization
az devops configure --defaults organization="https://dev.azure.com/campuslabs/"

# Get the list of repositories
$repos = az repos list --project $projectName --output json | ConvertFrom-Json

# Iterate over repositories
foreach ($repo in $repos) {
    $repoName = $repo.name
    $repoId = $repo.id

    Write-Host "Repository: $repoName"

    # Get the list of branches for the repository
    $branches = az repos ref list --filter "heads/"  --repository $repoId --project $projectName --output json | ConvertFrom-Json

    # Print the branch names
    foreach ($branch in $branches) {
        $branchName = $branch.name
        Write-Host "  Branch: $branchName"
    }
}
