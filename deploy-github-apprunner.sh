#!/bin/bash

REGION="us-east-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Get RDS endpoint (reuse existing)
RDS_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier gunicorn-app-postgres --query 'DBInstances[0].Endpoint.Address' --output text)

# Get VPC Connector ARN (reuse existing)
VPC_CONNECTOR_ARN=$(aws apprunner list-vpc-connectors --query 'VpcConnectors[0].VpcConnectorArn' --output text)

echo "Using RDS endpoint: $RDS_ENDPOINT"
echo "Using VPC Connector: $VPC_CONNECTOR_ARN"

# Create App Runner service from GitHub
aws apprunner create-service \
  --service-name gunicorn-app-github \
  --source-configuration "{
    \"CodeRepository\": {
      \"RepositoryUrl\": \"https://github.com/mzha999/gunicorn-app-runner\",
      \"SourceCodeVersion\": {
        \"Type\": \"BRANCH\",
        \"Value\": \"main\"
      },
      \"CodeConfiguration\": {
        \"ConfigurationSource\": \"REPOSITORY\",
        \"CodeConfigurationValues\": {
          \"Runtime\": \"PYTHON_3\",
          \"BuildCommand\": \"pip install -r requirements.txt\",
          \"StartCommand\": \"gunicorn --bind 0.0.0.0:8080 --workers 2 app:app\",
          \"Port\": \"8080\",
          \"RuntimeEnvironmentVariables\": {
            \"PORT\": \"8080\",
            \"DB_HOST\": \"$RDS_ENDPOINT\",
            \"DB_NAME\": \"postgres\",
            \"DB_USER\": \"postgres\",
            \"DB_PASSWORD\": \"MySecurePassword123\",
            \"DB_PORT\": \"5432\"
          }
        }
      }
    },
    \"AutoDeploymentsEnabled\": true
  }" \
  --network-configuration "{
    \"EgressConfiguration\": {
      \"EgressType\": \"VPC\",
      \"VpcConnectorArn\": \"$VPC_CONNECTOR_ARN\"
    }
  }" \
  --region $REGION

echo "GitHub-based App Runner service deployment initiated"