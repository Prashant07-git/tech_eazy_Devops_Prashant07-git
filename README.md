🚀 EC2 Automation DevOps Project (Spring Boot + AWS CLI + Bash)
This project automates the deployment of a Spring Boot application on an AWS EC2 instance using Bash scripting and AWS CLI. It installs Java 21, clones a GitHub repo, builds the project, deploys it, and shuts down the instance after a timeout.

📁 Folder Structure
vbnet
Copy
Edit
ec2-automation-devops/
│
├── Config/
│   ├── dev_config.sh
│   └── prod_config.sh
│
├── keys/
│   └── TechEasyKey.pem
│
├── scripts/
│   └── (Optional future scripts like shutdown.sh)
│
├── terraform/
│   └── (Optional Terraform files if used)
│
├── main.sh
├── README.md
├── .gitignore
⚙️ Prerequisites
Before running, ensure you have:

✅ An AWS account and a user with:

EC2 Full Access

IAM Role permissions (if planning further enhancements)

S3 permissions (if extending with logs backup)

✅ AWS CLI installed and configured (aws configure)

✅ Git and Bash installed (WSL, Git Bash, or Linux)

✅ A valid PEM key in keys/ (e.g., TechEasyKey.pem)

✅ Your EC2 key pair name matches the one in config

✅ Your GitHub Spring Boot repo (e.g., techeazy-devops) is public or accessible

🔧 Configuration
Inside Config/, create two config files:

✅ dev_config.sh
bash
Copy
Edit
AMI_ID="ami-07a6e3b1c102cdba8"
INSTANCE_TYPE="t2.micro"
KEY_NAME="TechEasyKey"
PEM_FILE="keys/TechEasyKey.pem"
REGION="ap-south-1"
APP_PORT=80
SHUTDOWN_TIMER=600
GIT_REPO="https://github.com/techeazy-consulting/techeazy-devops.git"
✅ prod_config.sh
Change values accordingly if using a different environment.

🏁 How to Run
Open terminal in the project root and run:

bash
Copy
Edit
bash main.sh Dev
Replace Dev with Prod for production.

🧠 What It Does (Step-by-Step)
Reads stage config (e.g., dev_config.sh)

Checks for existing EC2 Security Group

Launches a new EC2 instance with the given AMI

Waits for it to start and fetches public IP

SSH into instance:

Installs Java 21 (Adoptium)

Installs Git & Maven wrapper

Clones the Git repo

Builds the Spring Boot JAR

Runs the JAR on port 80

Waits 30 seconds and checks if app is reachable

Waits for 600 seconds (10 minutes) and stops the instance

📝 Future Improvements
☁️ Add S3 log upload after shutdown

🔐 Use IAM Roles instead of SSH

🧪 Add tests & CI/CD

🌐 Auto assign Elastic IP for persistent DNS

📦 Dockerize app deployment
