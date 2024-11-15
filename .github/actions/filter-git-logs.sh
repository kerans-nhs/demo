#!/bin/bash

# Define the repository directory
REPO_DIR="./"  # Set this to your Git repository path
OUTPUT_FILE="filtered_logs.csv"  # Output CSV file name
INCLUDE_KEYWORD="by team_id"  # The keyword or phrase to include
EXCLUDE_KEYWORD="cis2_example"  # The keyword or phrase to exclude

# Check if include keyword is provided
if [ -z "$INCLUDE_KEYWORD" ]; then
  echo "Usage: $0 <include_keyword> [exclude_keyword]"
  exit 1
fi

# Navigate to the Git repository directory
cd "$REPO_DIR" || { echo "Directory not found: $REPO_DIR"; exit 1; }

# Output header row to CSV file (remove "Message" column)
echo "Commit Hash,Date,Last_36_Chars,Changed_Files" > "$OUTPUT_FILE"

# Run git log, filter by include keyword, and process each commit
git log --pretty=format:"%H,%ad,%s" --date=short | grep -i "$INCLUDE_KEYWORD" | \
while IFS=, read -r commit_hash date message; do
  # Check if the exclude keyword is present in the message
  if [[ -n "$EXCLUDE_KEYWORD" && "$message" =~ $EXCLUDE_KEYWORD ]]; then
    continue  # Skip this commit if it contains the exclude keyword
  fi
  
  # Get the last 36 characters of the commit message (excluding the last character)
  last_36_chars="${message: -37:36}"
  
  # Get the list of changed files for this commit
  changed_files=$(git show --name-only --pretty="" "$commit_hash" | tr '\n' ';' | sed 's/;$//')
  
  # Output each line with the updated columns
  echo "$commit_hash,$date,\"$last_36_chars\",\"$changed_files\"" >> "$OUTPUT_FILE"
done

echo "Filtered logs saved to $OUTPUT_FILE"
