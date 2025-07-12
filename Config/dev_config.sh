# Development Configuration

INSTANCE_TYPE="t2.micro"
JAVA_VERSION="21"
GIT_REPO="https://github.com/techeazy-consulting/techeazy-devops.git"
APP_PORT="80"
REGION="ap-south-1"
AMI_ID="ami-03f4878755434977f"  # Amazon Linux 2023 in ap-south-1
SHUTDOWN_TIMER=600

# The correct key pair name you see in AWS:
KEY_NAME="TechEasy3"

# The corresponding PEM file present in your project directory
PEM_FILE="TechEasy3.pem"

S3_BUCKET="techeazy-app-logs-dev"
