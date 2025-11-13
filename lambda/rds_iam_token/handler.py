import os
import json
import boto3
import pg8000.native as pg # Team: I have used other modules, but will go with this.
from botocore.signers import RequestSigner

def generate_auth_token(region, host, port, user):
    rds = boto3.client("rds", region_name=region)

    # to Team from Juan: there are other ways of doing this, but will go with this.
    return rds.generate_db_auth_token(
        DBHostname=host, 
        Port=port, 
        DBUsername=user, 
        Region=region
    )

def lambda_handler(event, _context):
    region = event["region"]
    host   = event["db_host"]
    port   = int(event["db_port"])
    user   = event["db_user"]
    token  = generate_auth_token(region, host, port, user)
    return {"statusCode": 200, "token": token}