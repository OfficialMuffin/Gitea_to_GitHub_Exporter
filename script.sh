#!/bin/bash

# Prompt for Gitea credentials and URLs
read -p "Enter your Gitea URL (e.g., http://your-gitea-url.com): " GITEA_URL
read -p "Enter your Gitea username: " GITEA_USER
read -sp "Enter your Gitea personal access token: " GITEA_TOKEN
echo
read -p "Enter your GitHub username: " GITHUB_USER
read -sp "Enter your GitHub personal access token: " GITHUB_TOKEN
echo

# Parent directory to clone the repos into (optional but recommended)
PARENT_DIR=$(pwd)

# GitHub API URL for creating repositories
GITHUB_API_URL="https://api.github.com/user/repos"

# Initialize counter
repo_count=0

# Loop through your Gitea repositories and push them to GitHub
for repo in $(curl -s -u "$GITEA_USER:$GITEA_TOKEN" "$GITEA_URL/api/v1/user/repos" | jq -r '.[].name'); do
    # Clone the repository from Gitea using HTTPS
    echo "Cloning repository $repo from Gitea..."

    # Clone the repository into the parent directory
    git clone "http://$GITEA_USER:$GITEA_TOKEN@$GITEA_URL/$GITEA_USER/$repo.git" "$PARENT_DIR/$repo"

    # Check if the directory was created
    if [ ! -d "$PARENT_DIR/$repo" ]; then
        echo "Error: Failed to clone repository $repo. Skipping..."
        continue
    fi

    cd "$PARENT_DIR/$repo" || continue

    # Check if it's a valid Git repository
    if [ ! -d ".git" ]; then
        echo "Error: $repo is not a valid Git repository. Skipping..."
        cd "$PARENT_DIR" || continue
        continue
    fi

    # Check if the repository exists on GitHub
    echo "Checking if repository $repo exists on GitHub..."
    REPO_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" -u "$GITHUB_USER:$GITHUB_TOKEN" "$GITHUB_API_URL/$repo")

    # If the repository doesn't exist, create it on GitHub
    if [ "$REPO_EXISTS" -eq 404 ]; then
        echo "Repository $repo does not exist on GitHub. Creating repository..."
        curl -s -X POST -u "$GITHUB_USER:$GITHUB_TOKEN" \
            -d "{\"name\": \"$repo\"}" \
            "$GITHUB_API_URL"
    fi

    # Add GitHub remote (using HTTPS)
    echo "Adding GitHub remote for repository $repo..."
    git remote add github "https://$GITHUB_USER:$GITHUB_TOKEN@github.com/$GITHUB_USER/$repo.git"

    # Push all branches and tags to GitHub
    echo "Pushing repository $repo to GitHub..."
    git push github --all
    git push github --tags

    # Go back to the parent directory
    cd "$PARENT_DIR"

    echo "Finished pushing $repo to GitHub."

    # Increment the counter
    ((repo_count++))
done

# Print the total number of repositories pushed
echo "Total repositories pushed to GitHub: $repo_count"
