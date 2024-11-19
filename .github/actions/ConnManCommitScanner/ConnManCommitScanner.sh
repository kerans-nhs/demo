#!/bin/bash

set -e 

# Define variables
OUTPUT_FILE="filtered_connman_logs.csv"  # Output CSV file name
SUMMARY_FILE="summary_report.txt"  # Summary file name
INCLUDE_KEYWORD="by team_id"  # What to search for in commit message
EXCLUDE_KEYWORD="cis2_example"  # What commit messages to exclude
TEAM_ID_MAPPING="ConnManTeamIdMappings.json"  # JSON file with ID to human-readable name mapping

# Create CSV headers
echo "Commit Hash,Date,Team_Id,Supplier_Name,Environment,New_Config" > "$OUTPUT_FILE"

# Function to extract supplier name from JSON file
get_supplier_name() {
  local id=$1
  grep -o "\"$id\": *\"[^\"]*\"" "$TEAM_ID_MAPPING" | sed -E 's/.*: *"(.*)"/\1/' || echo "Unknown"
}

# Initialize counters
declare -A supplier_name_counts environment_counts
total_commits=0
total_new_configs=0

# Process Git logs and filter by INCLUDE_KEYWORD using process substitution
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
  if [[ -z "$changed_files" ]]; then
    continue  # Skip this commit if the changed_files is empty
  fi

  environment="${changed_files: 12:6}"
  echo "environment now set to $environment"
  
  # Determine New_Config value based on the message
  if [[ "$message" == *"created"* ]]; then
    new_config="true"
    total_new_configs=$((total_new_configs + 1))
  elif [[ "$message" == *"updated"* ]]; then
    new_config="false"
  else
    new_config="false"
  fi

  # Increment total commits
  total_commits=$((total_commits + 1))

  # Increment environment counters
  for env in $(echo "$environment" | tr ';' '\n'); do
    if [[ -n "${environment_counts["$env"]}" ]]; then
      environment_counts["$env"]=$((environment_counts["$env"] + 1))
    else
      environment_counts["$env"]=1
    fi
  done

  # Increment supplier_name counter
  if [[ -n "${supplier_name_counts["$supplier_name"]}" ]]; then
    supplier_name_counts["$supplier_name"]=$((supplier_name_counts["$supplier_name"] + 1))
  else
    supplier_name_counts["$supplier_name"]=1
  fi

  # Append to CSV
  echo "$commit_hash,$date,\"$team_id\",\"$supplier_name\",\"$environment\",\"$new_config\"" >> "$OUTPUT_FILE"
done < <(git log --since="1 week ago" --pretty=format:"%H,%ad,%s" --date=format-local:'%Y-%m-%d %H:%M:%S' | grep -i "$INCLUDE_KEYWORD")

# Generate summary report
{
  echo "Summary Report"
  echo "--------------"
  echo "Total Commits: $total_commits"
  echo
  echo "Commits per Supplier_Name:"
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
} > "$SUMMARY_FILE"

echo "Filtered logs saved to $OUTPUT_FILE"
echo "Summary report saved to $SUMMARY_FILE"
