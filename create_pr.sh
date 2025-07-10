#!/bin/bash

# auto-pr.sh
# A shell script for macOS to automate GitHub Pull Request creation using GitHub CLI.

# --- Configuration ---
# Default base branch if not provided by the user
DEFAULT_BASE_BRANCH="main"

# --- Functions ---

# Function to check if a command exists
command_exists () {
  command -v "$1" >/dev/null 2>&1
}

# Function to display error messages and exit
error_exit () {
  echo ""
  echo "❌ Error: $1" >&2
  echo ""
  exit 1
}

# Function to get user input with a default value
get_input_with_default() {
  local prompt="$1"
  local default_value="$2"
  local input_var_name="$3" # Name of the variable to store the input

  read -rp "$prompt (default: $default_value): " user_input
  if [[ -z "$user_input" ]]; then
    eval "$input_var_name=\"$default_value\""
  else
    eval "$input_var_name=\"$user_input\""
  fi
}

# --- Main Script Logic ---

echo "🚀 Starting GitHub Pull Request Automation Script"
echo "-------------------------------------------------"

# 1. Check for GitHub CLI installation
if ! command_exists gh; then
  error_exit "GitHub CLI (gh) is not installed. Please install it from https://cli.github.com/ and authenticate (gh auth login)."
fi

# 2. Check if we are in a Git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  error_exit "Not inside a Git repository. Please navigate to your repository."
fi

# 3. Get current branch name
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ -z "$CURRENT_BRANCH" ]]; then
  error_exit "Could not determine the current Git branch."
fi
echo "Current branch: $CURRENT_BRANCH"

# 4. Check for uncommitted changes
if [[ -n $(git status --porcelain) ]]; then
  echo "Detected uncommitted changes. Committing them now..."
  git add . || error_exit "Failed to stage changes."
  read -rp "Enter commit message for uncommitted changes: " UNCOMMITTED_COMMIT_MESSAGE
  if [[ -z "$UNCOMMITTED_COMMIT_MESSAGE" ]]; then
    error_exit "Commit message cannot be empty for uncommitted changes."
  fi
  git commit -m "$UNCOMMITTED_COMMIT_MESSAGE" || error_exit "Failed to commit changes."
  echo "Uncommitted changes committed."
else
  echo "No uncommitted changes detected."
fi

# 5. Push current branch to remote (if not already pushed or if local commits exist)
# Check if the local branch is behind or ahead of the remote
LOCAL_COMMITS=$(git rev-list @{u}..HEAD --count 2>/dev/null || echo 0)
REMOTE_COMMITS=$(git rev-list HEAD..@{u} --count 2>/dev/null || echo 0)

if [[ "$LOCAL_COMMITS" -gt 0 ]] || [[ -z $(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null) ]]; then
  echo "Pushing current branch ($CURRENT_BRANCH) to remote..."
  git push origin "$CURRENT_BRANCH" || error_exit "Failed to push branch to remote. Ensure the branch exists remotely or you have push permissions."
  echo "Branch pushed successfully."
else
  echo "Current branch is up-to-date with remote, no push needed."
fi


# 6. Gather PR details from user
echo ""
echo "--- Pull Request Details ---"

# Base branch
get_input_with_default "Enter the base branch (where you want to merge your changes)" "$DEFAULT_BASE_BRANCH" BASE_BRANCH

# PR Title
read -rp "Enter Pull Request Title: " PR_TITLE
if [[ -z "$PR_TITLE" ]]; then
  error_exit "Pull Request Title cannot be empty."
fi

# PR Description
echo "Enter Pull Request Description (press Ctrl+D when finished, or leave empty):"
PR_DESCRIPTION=$(cat)

# Optional: Reviewers
read -rp "Enter GitHub usernames for reviewers (comma-separated, optional): " REVIEWERS
REVIEWER_FLAG=""
if [[ -n "$REVIEWERS" ]]; then
  REVIEWER_FLAG="--reviewer $(echo "$REVIEWERS" | tr ',' ' ')"
fi

# Optional: Labels
read -rp "Enter labels (comma-separated, optional): " LABELS
LABEL_FLAG=""
if [[ -n "$LABELS" ]]; then
  LABEL_FLAG="--label $(echo "$LABELS" | tr ',' ' ')"
fi

# Optional: Draft PR
read -rp "Create as a draft Pull Request? (y/N): " DRAFT_CHOICE
DRAFT_FLAG=""
if [[ "$DRAFT_CHOICE" =~ ^[Yy]$ ]]; then
  DRAFT_FLAG="--draft"
fi

# 7. Create the Pull Request
echo ""
echo "Attempting to create Pull Request..."
echo "Source Branch: $CURRENT_BRANCH"
echo "Target Branch: $BASE_BRANCH"
echo "Title: $PR_TITLE"

# Construct the gh command
GH_COMMAND="gh pr create --base \"$BASE_BRANCH\" --head \"$CURRENT_BRANCH\" --title \"$PR_TITLE\" --body \"$PR_DESCRIPTION\" $REVIEWER_FLAG $LABEL_FLAG $DRAFT_FLAG"

# Execute the command
if eval "$GH_COMMAND"; then
  echo ""
  echo "✅ Pull Request created successfully!"
  echo "You can view it by running 'gh pr view --web'"
else
  error_exit "Failed to create Pull Request. Please check the output above for errors."
fi

echo ""
echo "Script finished."
