#!/bin/bash

set -e  # Exit on error

# Define variables
REPO_DIR="./"  # Repository directory
OUTPUT_FILE="filtered_logs.csv"  # Output CSV file name
INCLUDE_KEYWORD="by team_id"  # Hardcoded include keyword
EXCLUDE_KEYWORD="cis2_example"  # Hardcoded exclude keyword
MAPPING_FILE=".github/actions/ConnManCommitScanner/ConnManTeamIdMappings.json"  # JSON file with ID to human-readable name mapping

# Navigate to the repository
cd "$REPO_DIR" || { echo "Repository directory not found: $REPO_DIR"; exit 1; }

# Create CSV header
echo "Commit Hash,Date,Team_Id,Supplier_Name,Environment" > "$OUTPUT_FILE"

# Function to extract supplier name from JSON file
get_supplier_name() {
  local id=$1
  grep -o "\"$id\": *\"[^\"]*\"" "$MAPPING_FILE" | sed -E 's/.*: *"(.*)"/\1/' || echo "Unknown"
}

# Function to extract the 13th to 18th character of file names
extract_environment() {
  local file_list=$1
  local environment_list=""
  for file in $(echo "$file_list" | tr ';' '\n'); do
    # Extract characters 13 to 18
    environment_list+="${file:12:6};"
  done
  # Remove the trailing semicolon
  echo "${environment_list%?}"
}

# Process Git logs and filter by INCLUDE_KEYWORD
git log --since="1 week ago" --pretty=format:"%H,%ad,%s" --date=short | grep -i "$INCLUDE_KEYWORD" | \
while IFS=, read -r commit_hash date message; do
  # Exclude commits with the exclude keyword
  if [[ -n "$EXCLUDE_KEYWORD" && "$message" =~ $EXCLUDE_KEYWORD ]]; then
    continue
  fi

  # Extract the last 36 characters (excluding the final character) of the message
  team_id="${message: -37:36}"

  # Look up the supplier name for the team ID
  supplier_name=$(get_supplier_name "$team_id")

  # Get the changed files and extract the environment strings
  changed_files=$(git show --name-only --pretty="" "$commit_hash" | tr '\n' ';' | sed 's/;$//')
  environment=$(extract_environment "$changed_files")

  # Append to CSV
  echo "$commit_hash,$date,\"$team_id\",\"$supplier_name\",\"$environment\"" >> "$OUTPUT_FILE"
done

echo "Filtered logs saved to $OUTPUT_FILE"
