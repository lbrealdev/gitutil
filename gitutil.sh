#!/bin/bash

#set -x
set -euo pipefail
#trap cleanup SIGINT SIGTERM ERR EXIT

SCRIPT_BASE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

# gitlab variables
GL_API_URL="https://gitlab.com"

# github variables
GH_API_URL="https://api.github.com"

#cleanup() {
#  trap - SIGINT SIGTERM ERR EXIT
#}

# script menu.
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

function chk_repo() {
  HOST_PLATFORM="${2}"
  REPO_NAME="${3}"

  if [[ "$HOST_PLATFORM" == "gitlab" ]]; then
    curl -s -H "PRIVATE-TOKEN: ${GL_ACCESS_TOKEN}" "${GL_API_URL}/api/v4/projects/${REPO_NAME}" --stderr - | jq '.name'
  elif [[ "$HOST_PLATFORM" == "github" ]]; then
    curl -s -H "Authorization: token ${GH_ACCESS_TOKEN}" "${GH_API_URL}/repos/${GH_USER}/${REPO_NAME}" --stderr - | jq '.name'
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
