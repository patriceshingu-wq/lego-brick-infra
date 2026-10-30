# Prod: the "real" environment. Two servers in two Availability Zones, so one
# data center going down doesn't take everything down.
environment = "prod"

vpc_cidr = "10.30.0.0/16"

instance_type  = "t3.small"
instance_count = 2

# Prod can pin a more specific AMI pattern than dev/qa if you want fewer surprises:
# ami_name_filter = "al2023-ami-2023.6.*-x86_64"

# Separate key per environment (Part 4). Protect the prod key with a passphrase.
ssh_private_key_path = "~/.ssh/zero2ai-ec2-prod.pem"

allowed_ssh_cidrs = []

# Inbound "All traffic" rule (every protocol and port). Empty = closed.
# Example, let this environment's servers talk to each other freely:
# allowed_all_traffic_cidrs = ["10.30.0.0/16"]
allowed_all_traffic_cidrs = []
