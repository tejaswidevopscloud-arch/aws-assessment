"""
Lambda 1 – The Greeter
Triggered by GET /greet.
  1. Writes a record to the regional DynamoDB GreetingLogs table.
  2. Publishes a verification JSON payload to the Unleash live SNS topic.
  3. Returns 200 OK with the executing region.
"""

import json
import os
import uuid
from datetime import datetime, timezone

import boto3

DYNAMODB_TABLE = os.environ["DYNAMODB_TABLE"]
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]
EMAIL = os.environ["EMAIL"]
GITHUB_REPO = os.environ["GITHUB_REPO"]


def handler(event, context):
    region = os.environ.get("AWS_REGION", "unknown")
    now = datetime.now(timezone.utc).isoformat()

    # 1. Write greeting record to DynamoDB
    dynamodb = boto3.resource("dynamodb")
    table = dynamodb.Table(DYNAMODB_TABLE)
    table.put_item(
        Item={
            "id": str(uuid.uuid4()),
            "timestamp": now,
            "region": region,
            "email": EMAIL,
            "message": "Greet request processed",
        }
    )

    # 2. Publish verification payload to SNS (topic is in us-east-1)
    sns = boto3.client("sns", region_name="us-east-1")
    payload = {
        "email": EMAIL,
        "source": "Lambda",
        "region": region,
        "repo": GITHUB_REPO,
    }
    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Message=json.dumps(payload),
        Subject=f"Candidate Verification - Lambda - {region}",
    )

    # 3. Return success with executing region
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(
            {
                "message": "Greeting logged successfully",
                "region": region,
                "timestamp": now,
            }
        ),
    }
