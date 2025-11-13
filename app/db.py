import os
import json
import boto3
import psycopg2
from botocore.config import Config

# Hate using the environment variables approach
# Will change this to something more secure and repeatable
AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
DB_USER     = os.getenv("DB_USER")            # for boilerplate "app_user"
DB_NAME     = os.getenv("DB_NAME")            # for boilerplate "appdb"
DB_HOST     = os.getenv("DB_HOST")            # for boilerplate use the RDS Endpoint
DB_PORT     = int(os.getenv("DB_PORT", "5432"))
LAMBDA_ARN  = os.getenv("RDS_IAM_LAMBDA_ARN") 

_lambda = boto3.client("lambda", region_name=AWS_REGION, config=Config(retries={"max_attempts": 3}))

def get_iam_token():
    payload = {"db_host": DB_HOST, "db_port": DB_PORT, "db_user": DB_USER, "region": AWS_REGION}
    resp = _lambda.invoke(FunctionName=LAMBDA_ARN, Payload=json.dumps(payload))
    body = json.loads(resp["Payload"].read())
    return body["token"]

def get_db_conn():
    token = get_iam_token()
    return psycopg2.connect(
        host=DB_HOST,
        user=DB_USER,
        password=token,
        dbname=DB_NAME,
        port=DB_PORT,
        sslmode="require",
        connect_timeout=5,
    )

def get_db_time():
    with get_db_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT NOW();")
            return cur.fetchone()[0].isoformat()