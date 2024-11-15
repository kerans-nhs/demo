#!/bin/bash

set -e  # Exit on error

# Define variables (hardcoded values)
REPO_DIR="./"  # Repository directory (default to the current directory)
OUTPUT_FILE="filtered_logs.csv"  # Output CSV file name
INCLUDE_KEYWORD="by team_id"  # Hardcoded include keyword
EXCLUDE_KEYWORD="cis2_example"  # Hardcoded exclude keyword

# Navigate to the repository
cd "$REPO_DIR" || { echo "Repository directory not found: $REPO_DIR"; exit 1; }

# Create CSV header
echo "Commit Hash,Date,Last_36_Chars,Changed_Files" > "$OUTPUT_FILE"

# Process Git logs and filter by INCLUDE_KEYWORD
git log --pretty=format:"%H,%ad,%s" --date=short | grep -i "$INCLUDE_KEYWORD" | \
while IFS=, read -r commit_hash date message; do

  # Exclude commits with the exclude keyword
  if [[ -n "$EXCLUDE_KEYWORD" && "$message" =~ $EXCLUDE_KEYWORD ]]; then
    echo "Excluding commit: $commit_hash"
    continue
  fi

  # Extract the last 36 characters (excluding the final character) of the message
  last_36_chars="${message: -37:36}"

  # Get the changed files
  changed_files=$(git show --name-only --pretty="" "$commit_hash" | tr '\n' ';' | sed 's/;$//')

  # Append to CSV
  echo "$commit_hash,$date,\"$last_36_chars\",\"$changed_files\"" >> "$OUTPUT_FILE"
done

echo "Filtered logs saved to $OUTPUT_FILE"
