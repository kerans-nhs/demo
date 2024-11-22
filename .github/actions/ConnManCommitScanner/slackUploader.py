import os
from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError

# Fetch environment variables
# Get the bot token from the environment
SLACK_BOT_TOKEN = os.getenv("SLACK_BOT_TOKEN")
# Get the channel ID from the environment
CHANNEL_ID = os.getenv("CHANNEL_ID")

# Initialize Slack WebClient
client = WebClient(token=SLACK_BOT_TOKEN)

# File details
file_path = "report_summary.txt"  # Replace with the path to your CSV file
file_title = "Report Summary"
initial_comment = "This is a test."

try:
    # Upload the file
    response = client.files_upload_v2(
        file_uploads=[
            {
                "file": file_path,
                "title": file_title,
            }
        ],
        channel=CHANNEL_ID,
        initial_comment=initial_comment,
    )
    print("File uploaded successfully:", response)
except SlackApiError as e:
    print(f"Error uploading file: {e.response['error']}")
