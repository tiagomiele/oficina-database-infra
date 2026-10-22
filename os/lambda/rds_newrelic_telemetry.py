import json
import os
import time
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone

import boto3

CLOUDWATCH = boto3.client("cloudwatch")
LOGS = boto3.client("logs")
SQS = boto3.client("sqs")

METRICS = {
    "cpuUtilizationPercent": ("CPUUtilization", "Percent"),
    "databaseConnections": ("DatabaseConnections", "Count"),
    "freeStorageBytes": ("FreeStorageSpace", "Bytes"),
    "freeableMemoryBytes": ("FreeableMemory", "Bytes"),
    "readLatencySeconds": ("ReadLatency", "Seconds"),
    "writeLatencySeconds": ("WriteLatency", "Seconds"),
    "readIops": ("ReadIOPS", "Count/Second"),
    "writeIops": ("WriteIOPS", "Count/Second"),
}


def _latest_metric(identifier, metric_name, unit, started_at, ended_at):
    response = CLOUDWATCH.get_metric_statistics(
        Namespace="AWS/RDS",
        MetricName=metric_name,
        Dimensions=[{"Name": "DBInstanceIdentifier", "Value": identifier}],
        StartTime=started_at,
        EndTime=ended_at,
        Period=300,
        Statistics=["Average"],
        Unit=unit,
    )
    datapoints = response.get("Datapoints", [])
    if not datapoints:
        return None
    latest = max(datapoints, key=lambda datapoint: datapoint["Timestamp"])
    return latest.get("Average")


def _count_logs(log_group, filter_pattern, started_at_ms):
    total = 0
    next_token = None
    while True:
        arguments = {
            "logGroupName": log_group,
            "startTime": started_at_ms,
            "filterPattern": filter_pattern,
            "limit": 1000,
        }
        if next_token:
            arguments["nextToken"] = next_token
        response = LOGS.filter_log_events(**arguments)
        total += len(response.get("events", []))
        new_token = response.get("nextToken")
        if not new_token or new_token == next_token:
            return total
        next_token = new_token


def _events_endpoint(account_id, region):
    host = (
        "insights-collector.eu01.nr-data.net"
        if region.upper() == "EU"
        else "insights-collector.newrelic.com"
    )
    return f"https://{host}/v1/accounts/{account_id}/events"


def _send_event(event):
    request = urllib.request.Request(
        _events_endpoint(os.environ["NEW_RELIC_ACCOUNT_ID"], os.environ["NEW_RELIC_REGION"]),
        data=json.dumps(event, separators=(",", ":")).encode("utf-8"),
        headers={
            "Api-Key": os.environ["NEW_RELIC_LICENSE_KEY"],
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            if response.status < 200 or response.status >= 300:
                raise RuntimeError(f"New Relic respondeu HTTP {response.status}")
    except urllib.error.HTTPError as error:
        raise RuntimeError(f"New Relic respondeu HTTP {error.code}") from error


def _dlq_samples(prefix, environment):
    """Uma amostra por DLQ da Saga (filas com o prefixo do ambiente e sufixo -dlq)."""
    urls = SQS.list_queues(QueueNamePrefix=prefix).get("QueueUrls", [])
    samples = []
    for url in urls:
        name = url.rsplit("/", 1)[-1]
        if not name.endswith("-dlq"):
            continue
        attributes = SQS.get_queue_attributes(
            QueueUrl=url, AttributeNames=["ApproximateNumberOfMessages"]
        )["Attributes"]
        samples.append(
            {
                "eventType": "OficinaSqsSample",
                "timestamp": int(time.time() * 1000),
                "environment": environment,
                "queueName": name,
                "approximateNumberOfMessages": int(attributes["ApproximateNumberOfMessages"]),
            }
        )
    return samples


def handler(_event, _context):
    identifier = os.environ["RDS_INSTANCE_IDENTIFIER"]
    log_group = os.environ["RDS_LOG_GROUP_NAME"]
    ended_at = datetime.now(timezone.utc)
    metric_started_at = ended_at - timedelta(minutes=15)
    log_started_at = ended_at - timedelta(minutes=5)

    sample = {
        "eventType": "OficinaRdsSample",
        "timestamp": int(time.time() * 1000),
        "environment": os.environ["ENVIRONMENT"],
        "databaseIdentifier": identifier,
        "postgresErrorCount": _count_logs(
            log_group, "?ERROR ?FATAL ?PANIC", int(log_started_at.timestamp() * 1000)
        ),
        "slowQueryCount": _count_logs(
            log_group, '"duration:"', int(log_started_at.timestamp() * 1000)
        ),
    }

    for attribute, (metric_name, unit) in METRICS.items():
        value = _latest_metric(identifier, metric_name, unit, metric_started_at, ended_at)
        if value is not None:
            sample[attribute] = value

    _send_event(sample)
    dlq_prefix = os.environ.get("SQS_DLQ_PREFIX", "")
    if dlq_prefix:
        for dlq_sample in _dlq_samples(dlq_prefix, sample["environment"]):
            _send_event(dlq_sample)
    print(
        json.dumps(
            {
                "event": "RDS_TELEMETRY_SENT",
                "environment": sample["environment"],
                "databaseIdentifier": identifier,
                "metricCount": len(sample) - 6,
            },
            separators=(",", ":"),
        )
    )
    return {"status": "sent"}
