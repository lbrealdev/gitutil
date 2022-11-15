#!/bin/bash

# Exit on fail
set -euo pipefail

# Gitlab variables
GITLAB_API_URL="https://gitlab.com/api/v4/projects"
GITLAB_PROJECT_ID="$PROJECT_ID"
GITLAB_USER="akae_beka"
GITLAB_PROJECT_NAME=$(curl -s -H "PRIVATE-TOKEN: ${GITLAB_AUTH_TOKEN}" "${GITLAB_API_URL}/${GITLAB_PROJECT_ID}" | jq -r '.name')

# Github variables
GITHUB_API_URL="https://api.github.com"
GITHUB_USER="lbrealdev"
GITHUB_PROJECT_NAME="reposity-$GITLAB_PROJECT_NAME-migrate"

# Check if the repository exists in gitlab.
function check_gitlab_repository() {
  curl -s -H "PRIVATE-TOKEN: ${GITLAB_AUTH_TOKEN}" "${GITLAB_API_URL}/${GITLAB_PROJECT_ID}" | jq -r \
    'if .message == "404 Project Not Found" then "404" elif .message == "401 Unauthorized" then "401" else "200" end'
}

function check_github_repository() {
  curl -s -H "Authorization: token ${GITHUB_AUTH_TOKEN}" \
    "${GITHUB_API_URL}/repos/${GITHUB_USER}/${GITHUB_PROJECT_NAME}" | jq -r \
    'if .message == "Not Found" then "404" elif .message == "Bad credentials" then "401" else "200" end'
}

function create_github_repository() {
  curl -s -H "Authorization: token ${GITHUB_AUTH_TOKEN}" \
     -d "{
         \"name\": \"${GITHUB_PROJECT_NAME}\",
         \"auto_init\": \"true\",
         \"private\": \"true\"
       }" \
     "${GITHUB_API_URL}/user/repos" \
     -o /dev/null
}

function git_clone() {
  GITHUB_CLONE_URL=$(curl -s -H "Authorization: token ${GITHUB_AUTH_TOKEN}" "${GITHUB_API_URL}/repos/${GITHUB_USER}/${GITHUB_PROJECT_NAME}" | jq -r '.clone_url' | sed -E 's/https:\/\//https:\/\/'"$GITHUB_AUTH_TOKEN"'@/')
  mkdir migration && cd migration || exit
  git clone "$GITHUB_CLONE_URL" -q
  cd "$GITHUB_PROJECT_NAME" || exit
}

function git_migrate() {
  # Clone and pushing the source repository (Gitlab) for syncing into new repository (Github)
  GITLAB_CLONE_URL=$(curl -s -H "PRIVATE-TOKEN: ${GITLAB_AUTH_TOKEN}" "${GITLAB_API_URL}/${GITLAB_PROJECT_ID}" | jq -r '.http_url_to_repo' | sed -E 's/https:\/\//https:\/\/'"$GITLAB_USER"':'"$GITLAB_AUTH_TOKEN"'@/')
  git clone --bare "$GITLAB_CLONE_URL" -q
  BARE_REPO=$(echo "$GITLAB_CLONE_URL" | grep -oE '(/[^/]+){1}$' | cut -d "/" -f 2)
  cd "$BARE_REPO" || exit
  git push --mirror "$GITHUB_CLONE_URL" -q |& : || true
  cd ..
  git pull -q
  git checkout master -q
  git push origin master:main --force-with-lease -q
  git branch -f main origin/main -q
  git push origin --delete master -q
  git checkout main -q
  cd ../..
  rm -rf migration
  echo "New repository created in Github ${GITHUB_USER}"
  echo "Repository URL: $(curl -s -H "Authorization: token ${GITHUB_AUTH_TOKEN}" "${GITHUB_API_URL}/repos/${GITHUB_USER}/${GITHUB_PROJECT_NAME}" | jq -r '.html_url')"
}

function main() {
  if [ "$(check_gitlab_repository)" == "404" ]; then
    echo "This repository does not exist in gitlab, review project id. or your access credentials are invalid."
    exit
  elif [ "$(check_gitlab_repository)" == "200" ]; then
    echo "This repository exists in gitlab."
    echo "Checking if repository exists on github ..."
    if [ "$(check_github_repository)" == "404" ]; then
      echo "Repository does not exist on github starting migration ..."
      if [ ! -d "migration" ]; then
        create_github_repository
        git_clone
        git_migrate
      else
        echo "Failed, migration directory already exists"
        exit
      fi
    elif [ "$(check_github_repository)" == "200" ]; then
      echo "The repository already exists on github, please review your repository destination."
      exit
    elif [ "$(check_github_repository)" == "401" ]; then
      echo "Your Github personal access token are invalid."
    fi
  elif [ "$(check_gitlab_repository)" == "401" ]; then
    echo "Your Gitlab personal access token are invalid."
  else
    echo "Failed to execute git2git."
  fi
}

main