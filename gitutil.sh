#!/bin/bash

#set -x
set -euo pipefail
#trap cleanup SIGINT SIGTERM ERR EXIT

# SCRIPT_BASE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

# gitlab variables
GITLAB_API_URL="https://gitlab.com/api/v4/projects"

# github variables
GITHUB_API_URL="https://api.github.com"
GITHUB_USER="lbrealdev"

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
}

# Script menu.
menu_usage() {
  cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") --chk-repo <host-platform> <repo-name|id>

Script to manage your git repositories.

Available options:
-h, --help      Print this help and exit
-c, --chk-repo  Print script debug info
-f, --flag      Some flag description
EOF
  exit
}

# Check if the repository exists in gitlab.
function check_gitlab_repository() {
  curl -s -H "PRIVATE-TOKEN: ${GITLAB_AUTH_TOKEN}" "${GITLAB_API_URL}/${PROJECT_REPOSITORY}" | jq -r \
    'if .message == "404 Project Not Found" then "404" elif .message == "401 Unauthorized" then "401" else "200" end'
}

# Check if the repository exists in github.
function check_github_repository() {
  curl -s -H "Authorization: token ${GITHUB_AUTH_TOKEN}" \
    "${GITHUB_API_URL}/repos/${GITHUB_USER}/${PROJECT_REPOSITORY}" | jq -r \
    'if .message == "Not Found" then "404" elif .message == "Bad credentials" then "401" else "200" end'
}

function chk_repo() {
  HOST_PLATFORM="${2}"
  PROJECT_REPOSITORY="${3}"

  if [[ "$HOST_PLATFORM" == "gitlab" ]]; then
    if [ "$(check_gitlab_repository)" == "404" ]; then
      printf "This repository does not exist in gitlab."
      cleanup
    elif [ "$(check_gitlab_repository)" == "200" ]; then
      printf "Repository found!"
    elif [ "$(check_gitlab_repository)" == "401" ]; then
      printf "Your Gitlab personal access token are invalid."
      cleanup
    fi
  elif [[ "$HOST_PLATFORM" == "github" ]]; then
    if [[ "$(check_github_repository)" == "404" ]]; then
      printf "This repository does not exist in github."
    elif [ "$(check_github_repository)" == "200" ]; then
      printf "Repository found!"
    elif [ "$(check_github_repository)" == "401" ]; then
      printf "Your Github personal access token are invalid."
      cleanup
    fi
  fi
}

main() {

  while :; do
    case "${1-}" in
    -h | --help) menu_usage ;;
    -c | --chk-repo) chk_repo "$@"
      break ;;
    -f | --flag) echo "echo flag=1" 
      break ;;
    -?*) echo "Invalid param: $1" 
      break ;;
    *) echo "Missing param!" 
      break ;;
    esac
    shift
  done

  return 0
}

main "$@"
