"""
Lambda 2 – The Dispatcher
Triggered by POST /dispatch.
Calls the AWS ECS API to run a standalone Fargate task (RunTask).
Returns 200 OK with task details and executing region.
"""

import json
import os

import boto3


ECS_CLUSTER_ARN = os.environ["ECS_CLUSTER_ARN"]
ECS_TASK_DEFINITION = os.environ["ECS_TASK_DEFINITION"]
SUBNETS = os.environ["SUBNETS"].split(",")
SECURITY_GROUP = os.environ["SECURITY_GROUP"]
CONTAINER_NAME = os.environ.get("CONTAINER_NAME", "sns-publisher")


def handler(event, context):
    region = os.environ.get("AWS_REGION", "unknown")

    ecs = boto3.client("ecs")

    response = ecs.run_task(
        cluster=ECS_CLUSTER_ARN,
        taskDefinition=ECS_TASK_DEFINITION,
        launchType="FARGATE",
        count=1,
        networkConfiguration={
            "awsvpcConfiguration": {
                "subnets": SUBNETS,
                "securityGroups": [SECURITY_GROUP],
                "assignPublicIp": "ENABLED",
            }
        },
    )

    tasks = [t["taskArn"] for t in response.get("tasks", [])]
    failures = [f["reason"] for f in response.get("failures", [])]

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(
            {
                "message": "Fargate task dispatched",
                "region": region,
                "tasks": tasks,
                "failures": failures,
            }
        ),
    }
