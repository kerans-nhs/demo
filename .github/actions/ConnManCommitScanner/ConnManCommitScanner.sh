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
echo "Commit Hash,Date,Last_36_Chars,Human_Readable_Name,Changed_Files" > "$OUTPUT_FILE"

# Function to extract human-readable name from JSON file
get_human_readable_name() {
  local id=$1
  # Use grep and sed to extract the value for the ID from the JSON file
  grep -o "\"$id\": *\"[^\"]*\"" "$MAPPING_FILE" | sed -E 's/.*: *"(.*)"/\1/' || echo "Unknown"
}

# Process Git logs and filter by INCLUDE_KEYWORD
git log --pretty=format:"%H,%ad,%s" --date=short | grep -i "$INCLUDE_KEYWORD" | \
while IFS=, read -r commit_hash date message; do
  # Exclude commits with the exclude keyword
  if [[ -n "$EXCLUDE_KEYWORD" && "$message" =~ $EXCLUDE_KEYWORD ]]; then
    continue
  fi

  # Extract the last 36 characters (excluding the final character) of the message
  last_36_chars="${message: -37:36}"

  # Look up the human-readable name for the last 36 characters as an ID
  human_readable_name=$(get_human_readable_name "$last_36_chars")

  # Get the changed files
  changed_files=$(git show --name-only --pretty="" "$commit_hash" | tr '\n' ';' | sed 's/;$//')

  # Append to CSV
  echo "$commit_hash,$date,\"$last_36_chars\",\"$human_readable_name\",\"$changed_files\"" >> "$OUTPUT_FILE"
done

echo "Filtered logs saved to $OUTPUT_FILE"
