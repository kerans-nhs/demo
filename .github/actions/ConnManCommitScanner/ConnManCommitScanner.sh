#!/bin/bash

set -e 

# Define variables
OUTPUT_FILE="connman_commits.csv"  # Output CSV file name
SUMMARY_FILE="report_summary.txt"  # Summary file name
INCLUDE_KEYWORD="by team_id"  # What to search for in commit message
EXCLUDE_KEYWORD="cis2_example"  # What commit messages to exclude
TEAM_ID_MAPPING=".github/actions/ConnManCommitScanner/ConnManTeamIdMappings.json"  # JSON file with ID to human-readable name mapping

# Create CSV headers
echo "Commit Hash,Date,Team_Id,Supplier_Name,Environment,Config_Action" > "$OUTPUT_FILE"

# Function to extract supplier name from JSON file
get_supplier_name() {
  local id=$1
  jq -r --arg id "$id" '.[$id] // "Unknown"' "$TEAM_ID_MAPPING"
}

# Initialize counters
declare -A supplier_name_counts environment_counts new_config_counts
total_commits=0
total_new_configs=0
total_configs_deleted=0

# Process Git logs and filter by INCLUDE_KEYWORD using process substitution
while IFS=, read -r commit_hash date message; do
  # Exclude commits with the exclude keyword
  if [[ -n "$EXCLUDE_KEYWORD" && "$message" =~ $EXCLUDE_KEYWORD ]]; then
    continue
  fi

  # Get the changed files and extract the environment strings
  changed_files=$(git show --name-only --pretty="" "$commit_hash" | tr '\n' ';' | sed 's/;$//')
  if [[ -z "$changed_files" ]]; then
    continue  # Skip this commit if the changed_files is empty
  fi

  # Extract the last 37 characters (excluding the final character) of the message
  team_id="${changed_files: 19:36}"

  # Look up the supplier name for the team ID
  supplier_name=$(get_supplier_name "$team_id")
  
  # Determine New_Config value based on the message
  if [[ "$message" == *"created"* ]]; then
    config_action="Created"
    total_new_configs=$((total_new_configs + 1))
    new_config_counts["$supplier_name"]=$((new_config_counts["$supplier_name"] + 1))
  elif [[ "$message" == *"updated"* ]]; then
    config_action="Updated"
  elif [[ "$message" == *"deleted"* ]]; then
    config_action="Deleted"
    total_configs_deleted=$((total_configs_deleted + 1))
  else
    config_action="Unknown"
  fi

  # Increment total commits
  total_commits=$((total_commits + 1))
  
  environment="${changed_files: 12:6}"
  # Increment environment counters
  environment_counts["$environment"]=$((environment_counts["$environment"] + 1))

  # Increment supplier_name counter
  supplier_name_counts["$supplier_name"]=$((supplier_name_counts["$supplier_name"] + 1))

  # Append to CSV
  echo "$commit_hash,$date,\"$team_id\",\"$supplier_name\",\"$environment\",\"$config_action\"" >> "$OUTPUT_FILE"

done < <(git log --since="1 week ago" --pretty=format:"%H,%ad,%s" --date=format-local:'%Y-%m-%d %H:%M::%SZ' | grep -i "$INCLUDE_KEYWORD")


# Generate summary report
{
  echo "Summary Report"
  echo "--------------"
  echo "Total Commits: $total_commits"
  echo
  echo "Commits per Supplier:"
  for supplier_name in "${!supplier_name_counts[@]}"; do
    echo "$supplier_name: ${supplier_name_counts[$supplier_name]}"
  done
  echo
  echo "Commits per Environment:"
  for env in "${!environment_counts[@]}"; do
    echo "$env: ${environment_counts[$env]}"
  done
  echo 
  echo "Total number of new configs: $total_new_configs"
  echo
  echo "New Configs per Supplier_Name:"
  for supplier_name in "${!new_config_counts[@]}"; do
    echo "$supplier_name: ${new_config_counts[$supplier_name]}"
  done
  echo 
  echo "Total number deleted configs: $total_configs_deleted"
  echo
  
} > "$SUMMARY_FILE"

echo "Filtered logs saved to $OUTPUT_FILE"
echo "Summary report saved to $SUMMARY_FILE"
