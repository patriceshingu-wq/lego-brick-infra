# QA: where changes are tested before prod. Same shape as prod, smaller size.
environment = "qa"

vpc_cidr = "10.20.0.0/16"

instance_type  = "t3.micro"
instance_count = 1

# Separate key per environment (Part 4).
ssh_private_key_path = "~/.ssh/zero2ai-ec2-qa.pem"

allowed_ssh_cidrs = []

# Inbound "All traffic" rule (every protocol and port). Empty = closed.
# Example, let this environment's servers talk to each other freely:
# allowed_all_traffic_cidrs = ["10.20.0.0/16"]
allowed_all_traffic_cidrs = []
