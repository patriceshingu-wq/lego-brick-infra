# Dev: where you experiment. Smallest and cheapest. Break it freely.
environment = "dev"

# Each env gets its own non-overlapping range, so they could be connected later.
vpc_cidr = "10.10.0.0/16"

instance_type  = "t3.micro"
instance_count = 1

# SSH key for THIS environment, made with ssh-keygen (Part 4). Each environment
# has its own key, so a leaked dev key can't open prod.
ssh_private_key_path = "~/.ssh/zero2ai-ec2-dev.pem"

# Your own public IP is looked up and allowed automatically (allow_my_ip).
# List any extra addresses here, e.g. allowed_ssh_cidrs = ["203.0.113.10/32"]
allowed_ssh_cidrs = []

# Inbound "All traffic" rule (every protocol and port). Empty = closed.
# Example, let this environment's servers talk to each other freely:
# allowed_all_traffic_cidrs = ["10.10.0.0/16"]
allowed_all_traffic_cidrs = []
