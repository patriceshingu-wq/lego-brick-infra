# Chapter 08 — Build bigger in the cloud

> Matches **Chapter 08** in the book. The Terraform project for this chapter is in the
> [`terraform/`](terraform) folder.

**Labels:** 💳 Needs an account that may cost money · 🌐 Needs the internet · 🧑‍🤝‍🧑 Easier with a helper the first time

---

## The big idea (in plain words)

In [Chapter 07](../chapter-07-terraform) you wrote one `main.tf` file and built one server.
That's perfect for a first try. Real teams need more:

- They build the **same** setup several times: one copy to experiment in (**dev**), one to test
  changes in (**qa**), and the real one customers use (**prod**).
- Several people work on it, so Terraform's records can't live on one person's laptop.
- Nobody wants to copy and paste the same code three times.

Professionals solve this with four habits, and you'll use all four in this chapter:

1. **Modules.** A module is a reusable building block, like a LEGO brick. You write the "server"
   brick once and snap it into every environment.
2. **A remote backend.** Terraform keeps a record (the **state file**) of everything it built.
   You'll store it in an **S3 bucket** (a folder in the cloud) so it's safe, backed up, and
   shared.
3. **State locking.** A small **DynamoDB table** acts like a "do not disturb" sign. While one
   person runs `apply`, nobody else can run it at the same time and mess up the record.
4. **Environments as settings files.** dev, qa, and prod use the **same code**. Only a short
   settings file (`dev.tfvars`, `qa.tfvars`, `prod.tfvars`) is different.

You'll also make the operating system image (the **AMI**) a setting. Terraform looks up the
newest matching image every time, using a search pattern stored in `variables.tf`.

> **Chapter 10 uses this same project layout.** It reuses the same backend (bucket and lock
> table), the same `modules/` folder, and the same dev / qa / prod environments. It adds a new
> stack next to `ec2/`. Learn the layout well here and Chapter 10 will feel familiar.

Plan for about **60 minutes**.

## New words (look up anything unfamiliar in the [GLOSSARY](../GLOSSARY.md))

- **Module**: A folder of Terraform code you can reuse, filling in a few blanks (variables) each
  time.
- **Root module / stack**: The folder you actually run `terraform` in. It snaps modules
  together. In this chapter that's `terraform/ec2/`.
- **State file**: Terraform's record of what it has built (`terraform.tfstate`). Terraform reads
  it to know what already exists.
- **Backend**: Where the state file is stored. Chapter 07 kept it on your laptop. This chapter
  keeps it in S3.
- **S3 bucket**: A folder in AWS for storing files. Bucket names must be unique across all of AWS.
- **DynamoDB table**: A simple AWS database. Here it holds one small row: the lock.
- **State locking**: Stops two people from changing the same infrastructure at the same time.
- **Environment**: A separate copy of your setup, such as dev, qa, or prod.
- **`.tfvars` file**: A settings file that fills in variables for one environment.
- **`.tfbackend` file**: A settings file that tells Terraform where to store one environment's
  state.
- **AMI (Amazon Machine Image)**: A ready-made copy of an operating system that a server starts
  from.
- **VPC (Virtual Private Cloud)**: Your own private network inside AWS. Each environment gets one.
- **Subnet**: A smaller slice of a VPC, inside one data center (Availability Zone).
- **Security group**: A firewall around your servers. It lists who may connect, and on which port.
- **SSH**: A secure way to log in to a remote computer from your terminal.

## What you will build

```text
terraform/
├── backend/                 # Run ONCE. Creates the S3 bucket + DynamoDB lock table.
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── modules/                 # Reusable LEGO bricks. You never run terraform in here.
│   ├── vpc/                 #   a private network with public subnets
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   └── ec2/                 #   AMI lookup + security group + key pair + servers
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── versions.tf
└── ec2/                     # The stack you run. Snaps the bricks together.
    ├── main.tf
    ├── variables.tf         #   includes the AMI search pattern
    ├── outputs.tf
    └── environments/
        ├── dev.tfvars       #   settings for each environment
        ├── qa.tfvars
        ├── prod.tfvars
        ├── dev.tfbackend    #   where each environment's state is stored
        ├── qa.tfbackend
        └── prod.tfbackend
```

When you run it, each environment gets its own network and servers, and its own state file in
the shared bucket:

| Environment | Network (VPC)  | Servers           | State file in S3             |
| ----------- | -------------- | ----------------- | ---------------------------- |
| dev         | `10.10.0.0/16` | 1 × `t3.micro`    | `ec2/dev/terraform.tfstate`  |
| qa          | `10.20.0.0/16` | 1 × `t3.micro`    | `ec2/qa/terraform.tfstate`   |
| prod        | `10.30.0.0/16` | 2 × `t3.small`    | `ec2/prod/terraform.tfstate` |

---

## ⚠️ Money and safety: read this before you start

The rules are the same as Chapter 07, plus a few new ones:

- **Build one environment at a time, then destroy it.** `t3.micro` and `t3.small` are Free
  Tier eligible. Running dev for an hour costs about one cent. Prod has two servers, so it costs
  a bit more, and your credits cover it.
- **The S3 bucket and DynamoDB table cost almost nothing** (fractions of a cent per month at
  this size). You can leave them in place until you finish Chapter 10.
- **Always run `terraform destroy` for each environment you built.** Part 8 shows how.
- **Never commit SSH private keys or state files to GitHub.** This repo's `.gitignore`
  already ignores `*.tfstate` and `.terraform/` (this chapter's `.gitignore` also ignores `*.pem`),
  and you keep your SSH keys in `~/.ssh`, outside the project. Terraform never sees them.
- Your Chapter 07 **budgets** are still watching. They warn you; they don't stop spending.

## What you need before you start

- [ ] **Chapter 07 finished**: AWS account with MFA, budgets, the `terraform-student` user, the
      AWS CLI, and Terraform installed.
- [ ] `aws sts get-caller-identity` shows `user/terraform-student`.
- [ ] `terraform -version` shows `v1.5` or newer.

---

## Part 1: Give your IAM user two more permissions

In Chapter 07 your `terraform-student` user could only manage EC2. Now Terraform also needs to
create an S3 bucket and a DynamoDB table.

1. Sign in to the AWS Console as the **root user**. (Only the root user can change permissions
   right now.)
2. Search for **IAM** and open it. Click **Users**, then **terraform-student**.
3. Open the **Permissions** tab and click **Add permissions → Add permissions**.
4. Choose **Attach policies directly**.
5. Search for and tick **`AmazonS3FullAccess`**.
6. Clear the search, then search for and tick **`AmazonDynamoDBFullAccess`**.
7. Click **Next**, then **Add permissions**.

**What you should see:** three policies on the Permissions tab: `AmazonEC2FullAccess`,
`AmazonS3FullAccess`, and `AmazonDynamoDBFullAccess`.

> VPCs, subnets, and security groups are part of EC2, so `AmazonEC2FullAccess` already covers them.

---

## Part 2: Read the project before you run it

Open the `chapter-08-cloud/terraform` folder in your editor.

### 2a. `backend/main.tf`: the shared, locked notebook

This stack creates two things. Every other stack in this chapter (and in Chapter 10) stores its
state there.

```hcl
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "tf_state" {
  bucket        = "${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}
```

- `aws_caller_identity` looks up your 12-digit account number. Adding it to the name makes the
  bucket name unique across all of AWS, for example `zero2ai-tfstate-123456789012`.
- The file also turns on **versioning** (every old copy of the state is kept), **encryption**,
  and **blocks all public access**. State files can contain secrets.

```hcl
resource "aws_dynamodb_table" "tf_lock" {
  name         = "${var.project_name}-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  ...
}
```

- This is the lock table. When you run `plan` or `apply`, Terraform writes a row with the
  `LockID`. If someone else tries at the same time, they get an error saying the state is
  locked. When you finish, the row is removed.
- `PAY_PER_REQUEST` means you pay only when it's used: fractions of a cent.

> **Why does the backend stack keep its own state on your laptop?** It creates the bucket.
> The bucket doesn't exist until this stack runs, so this one stack can't store its state there.
> Its state file stays in `terraform/backend/`. Don't delete it.

### 2b. `modules/vpc/`: a private network brick

It creates a **VPC** using the address range you give it, an **internet gateway** (the door to
the internet), and **public subnets** in different Availability Zones. Look at this line:

```hcl
cidr_block = cidrsubnet(var.cidr_block, 8, count.index + 1)
```

It cuts the VPC range into smaller `/24` slices automatically: `10.10.1.0/24`, `10.10.2.0/24`,
and so on. You never type subnet ranges by hand.

There's also a `subnet_tags` variable that adds extra labels to the subnets. Chapter 10 uses it
to tag the subnets so Kubernetes can find them.

### 2c. `modules/ec2/`: the server brick, with a dynamic AMI

The first block looks up the AMI:

```hcl
data "aws_ami" "selected" {
  most_recent = true
  owners      = var.ami_owners

  filter {
    name   = "name"
    values = [var.ami_name_filter]
  }
}
```

In Chapter 07 the search pattern was typed straight into the code. Now it comes from a
**variable**, so you can change the operating system without editing the module.

- `var.ami_name_filter` is the name to search for. `*` means "anything here".
- `var.ami_owners` says who must own the image (`amazon`). This stops you from picking up a
  look-alike image made by a stranger.
- `most_recent = true`: if several images match, use the newest one.

The rest of the module creates:

- A **security group** (firewall). All outbound traffic is allowed. Inbound **SSH** (port 22)
  is allowed **only** from the addresses in `allowed_ssh_cidrs`. The `ec2` stack fills that list
  with your own public IP automatically (Part 4), so nobody else can reach port 22.
  An optional inbound **All traffic** rule (every protocol and port) is created only for the
  addresses in `allowed_all_traffic_cidrs`. It's empty by default, so the rule doesn't exist
  until you add a range.
- A **key pair**, when `create_key_pair = true`. The `ec2` stack turns this on and passes in the
  **public** key you made with `ssh-keygen` (Part 4).
- `instance_count` **servers**, spread across the subnets. Each one uses the looked-up AMI, has
  an encrypted disk, and requires **IMDSv2** (a security setting that protects the server's
  credentials).

### 2d. `ec2/variables.tf`: where the AMI is chosen

```hcl
variable "ami_name_filter" {
  type    = string
  default = "al2023-ami-2023.*-x86_64"
}

variable "ami_owners" {
  type    = list(string)
  default = ["amazon"]
}
```

These are the two settings the lookup uses. The defaults find the newest **Amazon Linux 2023**
image. Any environment's `.tfvars` file can override them.

### 2e. `ec2/main.tf`: snapping the bricks together

```hcl
terraform {
  backend "s3" {}
  ...
}
```

The backend block is **empty on purpose**. If the bucket and file name were written here, dev,
qa, and prod would all share one state file and overwrite each other. Instead, you supply the
details when you run `terraform init` (Part 5).

```hcl
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Stack       = local.stack
      Environment = var.environment
      Owner       = var.owner
      ManagedBy   = "terraform"
    }
  }
}
```

`default_tags` puts these labels on **every** resource automatically. In the AWS Console you
can tell at a glance which environment a server belongs to.

```hcl
module "vpc" {
  source      = "../modules/vpc"
  name_prefix = local.name_prefix
  cidr_block  = var.vpc_cidr
  ...
}

module "ec2" {
  source          = "../modules/ec2"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.public_subnet_ids
  ami_name_filter = var.ami_name_filter
  ami_owners      = var.ami_owners
  ...
}
```

Each `module` block snaps in a brick and fills in its blanks. Notice how the `ec2` brick
receives `module.vpc.vpc_id`: one brick's **output** becomes another brick's **input**.

### 2f. `ec2/environments/`: the only part that differs

`dev.tfvars`:

```hcl
environment    = "dev"
vpc_cidr       = "10.10.0.0/16"
instance_type  = "t3.micro"
instance_count = 1
ssh_private_key_path = "~/.ssh/zero2ai-ec2-dev.pem"
allowed_ssh_cidrs = []
```

`prod.tfvars` uses `10.30.0.0/16`, `t3.small`, and **2** servers. Same code, different
settings.

`dev.tfbackend`:

```hcl
key            = "ec2/dev/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "zero2ai-terraform-locks"
encrypt        = true
```

This tells Terraform which file in the bucket belongs to dev, and which table to lock. The
bucket name isn't in the file because it contains your account number. You'll pass it in from
the backend's output.

---

## Part 3: Create the backend (once)

```bash
cd chapter-08-cloud/terraform/backend
terraform init
terraform plan
```

**What you should see:** `Plan: 5 to add, 0 to change, 0 to destroy.` (bucket, versioning,
encryption, public-access block, lock table).

```bash
terraform apply
```

Type **`yes`**. After a few seconds:

```text
Outputs:

account_id   = "123456789012"
lock_table   = "zero2ai-terraform-locks"
region       = "us-east-1"
state_bucket = "zero2ai-tfstate-123456789012"
```

**Check in the Console:** open **S3** and find `zero2ai-tfstate-<your account number>` (empty
for now). Open **DynamoDB → Tables** and find `zero2ai-terraform-locks`.

---

## Part 4: Create your SSH keys and how SSH access works

This part copies how real teams handle server access in production:

- **You create the key yourself, on your own machine.** Terraform only reads the **public** key
  (`.pub`) and registers it with AWS. The private key (`.pem`) never goes into Terraform, so it
  never ends up in the state file in S3, where anyone with access to the bucket could read it.
- **One key per environment.** If your dev key leaks, prod is still safe. You can also replace
  (rotate) one environment's key without touching the others.
- **SSH is open only to your IP**, never to the whole internet (`0.0.0.0/0`).

### Step 1: Create one key per environment

```bash
ssh-keygen -t rsa -b 4096 -m PEM -C "zero2ai-dev"  -f ~/.ssh/zero2ai-ec2-dev.pem
ssh-keygen -t rsa -b 4096 -m PEM -C "zero2ai-qa"   -f ~/.ssh/zero2ai-ec2-qa.pem
ssh-keygen -t rsa -b 4096 -m PEM -C "zero2ai-prod" -f ~/.ssh/zero2ai-ec2-prod.pem
```

(On Windows PowerShell, use `-f $HOME\.ssh\zero2ai-ec2-dev.pem` and so on.)

- `-m PEM` saves the private key in PEM format, the same `.pem` format AWS gives you when you
  create a key in the Console.
- Each command asks for a **passphrase**. Press Enter twice to skip it for dev and qa. **Set one
  for prod.** Then, even if someone copies the file, they can't use it without the passphrase.

Each command creates two files:

| File | What it is | Who gets it |
| --- | --- | --- |
| `~/.ssh/zero2ai-ec2-dev.pem` | **Private** key | Only you. Never share it, never commit it. |
| `~/.ssh/zero2ai-ec2-dev.pem.pub` | **Public** key | Terraform reads it and gives it to AWS. |

Lock the private keys down so only you can read them (`ssh` refuses to use a key that others
can read):

```bash
chmod 400 ~/.ssh/zero2ai-ec2-*.pem
```

### Step 2: Check the path in each `.tfvars` file

Each environment's `.tfvars` file says which key it uses:

```hcl
ssh_private_key_path = "~/.ssh/zero2ai-ec2-dev.pem"
```

Terraform checks that the `.pem` file and its `.pem.pub` file both exist **before** it plans
anything. If either one is missing, it stops with `SSH key not found` and shows you the
`ssh-keygen` command to run.

### Step 3: Your IP is allowed automatically

On every `plan`, Terraform asks `https://checkip.amazonaws.com` for your public IP
(`data "http" "my_ip"`) and adds it to `allowed_ssh_cidrs` with `/32` at the end (that means
"only this one address"). To see it yourself:

```bash
curl https://checkip.amazonaws.com
```

To let another address in too (for example, a teammate or an office), list it in the `.tfvars`
file:

```hcl
allowed_ssh_cidrs = ["203.0.113.10/32"]
```

When Terraform runs from a CI pipeline (Chapter 09), the "current IP" would be the CI server's,
not yours. Set `allow_my_ip = false` there and list the allowed addresses explicitly.

> Your home IP can change. If SSH stops working another day, just run `apply` again: the
> lookup picks up your new IP and updates the rule.

#### Optional: allow all inbound traffic from a trusted range

Sometimes servers need to reach each other on many ports (for example, an app talking to a
database). Instead of adding one rule per port, you can add an inbound **All traffic** rule
(protocol `-1` = every protocol and port) for a range you trust. List it in the `.tfvars` file:

```hcl
# dev.tfvars: let dev's servers talk to each other on any port
allowed_all_traffic_cidrs = ["10.10.0.0/16"]
```

Run `plan` and you'll see one extra `aws_vpc_security_group_ingress_rule.all_traffic` per range.
To remove the rule, set the list back to `[]` and run `apply`.

> ⚠️ Never put `"0.0.0.0/0"` here. That opens **every** port on your servers to the whole
> internet. Use your VPC range or a single `/32` address.

### Rotating a key

Teams replace keys regularly, and right away when someone leaves or a laptop is lost. To
rotate the dev key, make a new key at the same path and apply:

```bash
rm -f ~/.ssh/zero2ai-ec2-dev.pem ~/.ssh/zero2ai-ec2-dev.pem.pub
ssh-keygen -t rsa -b 4096 -m PEM -C "zero2ai-dev" -f ~/.ssh/zero2ai-ec2-dev.pem
chmod 400 ~/.ssh/zero2ai-ec2-dev.pem
terraform apply -var-file=environments/dev.tfvars
```

The plan **replaces** the key pair and the servers, because AWS only adds a key to a server
when it is first built. That's fine for these practice servers. In production, teams avoid
rebuilding servers by putting the new public key on them with a configuration tool, or skip SSH
keys entirely with **AWS Systems Manager Session Manager**.

---

## Part 5: Build dev, check it, delete it

```bash
cd ../ec2
```

### Step 1: `terraform init` with the dev backend

```bash
terraform init -reconfigure \
  -backend-config=environments/dev.tfbackend \
  -backend-config="bucket=$(terraform -chdir=../backend output -raw state_bucket)"
```

- `-backend-config=environments/dev.tfbackend` reads the dev state file name and lock table.
- `-backend-config="bucket=$(...)"` asks the backend stack for the bucket name and passes it in.
- `-reconfigure` says "forget the previous environment's backend". You need it every time you
  switch environments.

(On Windows PowerShell, put the whole command on one line and remove the `\` characters.)

**What you should see:** `Successfully configured the backend "s3"!` and
`Terraform has been successfully initialized!`

### Step 2: `terraform plan` with the dev settings

```bash
terraform plan -var-file=environments/dev.tfvars
```

**What you should see:** `Plan: 12 to add, 0 to change, 0 to destroy.` Look through the list:
a VPC, internet gateway, two subnets, a route table and its two associations, a security group
with its outbound rule and an SSH rule for your IP, a key pair made from your `.pem.pub` file,
and **one** `aws_instance`. Notice there is no private key anywhere in the plan.

Also look for the `ami` line on the instance. Terraform has already looked up the newest image.

### Step 3: `terraform apply`

```bash
terraform apply -var-file=environments/dev.tfvars
```

Type **`yes`**. After about a minute:

```text
Outputs:

ami_id       = "ami-0abc123..."
ami_name     = "al2023-ami-2023.x.xxxxxxxx.x-kernel-6.x-x86_64"
environment  = "dev"
instance_ids = ["i-0abc..."]
server_ips   = ["54.123.45.67"]
ssh_allowed_cidrs    = ["198.51.100.7/32"]
ssh_commands         = ["ssh -i /Users/you/.ssh/zero2ai-ec2-dev.pem ec2-user@54.123.45.67"]
ssh_private_key_path = "/Users/you/.ssh/zero2ai-ec2-dev.pem"
vpc_id       = "vpc-0abc..."
```

`ami_name` shows you exactly which image the lookup picked.

**Check it in the Console** (region **N. Virginia**):

1. **EC2 → Instances**: you see **zero2ai-ec2-dev-1**, **Running**. Click it, open the
   **Tags** tab, and find `Environment = dev`, `ManagedBy = terraform`, and the other
   `default_tags`.
2. **VPC → Your VPCs**: you see **zero2ai-ec2-dev-vpc** with `10.10.0.0/16`.
3. **S3 → your state bucket**: open `ec2/` → `dev/`. There's `terraform.tfstate`. That's
   Terraform's record of what it just built, stored safely in the cloud.

**Log in.** Wait about a minute for the server to boot, then paste the command from
`ssh_commands`:

```bash
ssh -i ~/.ssh/zero2ai-ec2-dev.pem ec2-user@54.123.45.67
```

Type `yes` the first time. You're now on your cloud server. Type `exit` to leave.

### Step 4: `terraform destroy`

```bash
terraform destroy -var-file=environments/dev.tfvars
```

Type **`yes`**.

**What you should see:** `Destroy complete! Resources: 10 destroyed.` (or 11–12 with SSH).

> Always pass the **same** `-var-file` to `plan`, `apply`, and `destroy`. The settings file and
> the backend you initialized must be for the same environment.

---

## Part 6: Build qa or prod: same code, different settings

To switch environments, run `init` again with the other `.tfbackend` file, then use the matching
`.tfvars` file. Here's prod:

```bash
terraform init -reconfigure \
  -backend-config=environments/prod.tfbackend \
  -backend-config="bucket=$(terraform -chdir=../backend output -raw state_bucket)"

terraform plan -var-file=environments/prod.tfvars
```

**What you should see:** **two** `aws_instance` resources, `instance_type = "t3.small"`, and a
VPC with `10.30.0.0/16`. You didn't change any code, only the settings file.

If you want to build it, run `apply`, check that the two servers are in **different**
Availability Zones (the **Availability Zone** column in EC2 → Instances), then **destroy it
straight away**:

```bash
terraform apply   -var-file=environments/prod.tfvars
terraform destroy -var-file=environments/prod.tfvars
```

qa works the same way with `qa.tfbackend` and `qa.tfvars`.

> **See the lock in action.** Open a second terminal in the same folder and run `terraform
> plan -var-file=environments/prod.tfvars` while the first terminal is waiting at an `apply`
> prompt. The second terminal fails with `Error acquiring the state lock`. That's DynamoDB
> keeping two people from changing prod at the same time.

---

## Part 7: Change the AMI with one variable

Because the AMI search pattern is a variable, you can switch the operating system from the
command line or a `.tfvars` file. No module changes needed.

Preview **Ubuntu 24.04** for dev:

```bash
terraform init -reconfigure \
  -backend-config=environments/dev.tfbackend \
  -backend-config="bucket=$(terraform -chdir=../backend output -raw state_bucket)"

terraform plan -var-file=environments/dev.tfvars \
  -var='ami_name_filter=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*' \
  -var='ami_owners=["099720109477"]'
```

`099720109477` is Canonical's account (the company that makes Ubuntu). The plan shows a
different `ami` ID. On Ubuntu the login user is `ubuntu` instead of `ec2-user`.

To make the change permanent for one environment, put those two lines in its `.tfvars` file
instead of passing `-var`.

> **Why might `plan` say a server "must be replaced"?** `most_recent = true` always picks the
> newest image. When AWS publishes a patched image, the lookup returns a new ID, and Terraform
> wants to rebuild the server with it. That's normal. In prod, teams often pin a more specific
> pattern (see the commented line in `prod.tfvars`) so it only changes when they choose.

---

## Part 8: Clean up

**After every session**, destroy each environment you built. For each one (dev shown):

```bash
cd chapter-08-cloud/terraform/ec2
terraform init -reconfigure \
  -backend-config=environments/dev.tfbackend \
  -backend-config="bucket=$(terraform -chdir=../backend output -raw state_bucket)"
terraform destroy -var-file=environments/dev.tfvars
```

If an environment was already destroyed, Terraform says `0 destroyed`. That's fine.

**Keep the backend for Chapter 10.** The bucket and lock table cost almost nothing, and
Chapter 10 stores its state in them.

**When you're completely done with Chapters 08 and 10**, destroy the backend **last**. Destroy
every environment first, because destroying the bucket deletes every state file in it:

```bash
cd ../backend
terraform destroy
```

---

## How Chapter 10 reuses this

Chapter 10 uses the same layout. It doesn't start from scratch:

```text
terraform/
├── backend/          # same bucket + lock table (already created, don't recreate)
├── modules/
│   ├── vpc/          # same VPC brick, with subnet_tags for Kubernetes
│   ├── ec2/
│   └── ...           # new bricks for the cluster
├── ec2/              # this chapter's stack
└── eks/              # Chapter 10's stack: main.tf, variables.tf, environments/dev|qa|prod
```

- **Same backend:** the same S3 bucket and DynamoDB table, with state keys like
  `eks/dev/terraform.tfstate` next to `ec2/dev/terraform.tfstate`.
- **Same modules:** the `vpc` brick is reused unchanged.
- **Same environments:** `dev`, `qa`, and `prod` `.tfvars` and `.tfbackend` files, and the same
  `init -reconfigure` → `plan` → `apply` → `destroy` routine.
- **No name clashes:** names include the stack (`zero2ai-ec2-dev-...` vs `zero2ai-eks-dev-...`),
  so both stacks can exist in one account.

---

## Try it yourself (mini challenges)

Destroy anything you build before moving on.

- **Trace a blank.** `modules/ec2/main.tf` uses `var.instance_type`. Find where the module
  lists that blank, where `ec2/main.tf` passes it in, and where `prod.tfvars` fills it in.
- **Scale dev.** In `dev.tfvars`, change `instance_count = 1` to `2`. Run `plan`. How many
  servers does it add? Which subnets do they go in? (Hint: look at the `%` in
  `modules/ec2/main.tf`.)
- **Try ARM.** Plan dev with `-var='ami_name_filter=al2023-ami-2023.*-arm64'` and
  `-var='instance_type=t4g.micro'`. Why must the instance type change too? What happens if you
  change only the AMI?
- **Find the state files.** After building dev and then prod, open your bucket in the S3
  Console. How many state files are there, and in which folders? Click **Show versions**. Why
  are there several versions of each?
- **Think it through.** Why is it dangerous to give dev and prod the same `key` in their
  `.tfbackend` files? What would happen on the next `apply`?

---

## If something breaks

- **`AccessDenied` on `s3:CreateBucket` or `dynamodb:CreateTable`**: Your IAM user is missing the
  permissions from Part 1. Check that `AmazonS3FullAccess` and `AmazonDynamoDBFullAccess` are
  attached to `terraform-student`.
- **`BucketAlreadyExists`**: Someone else in the world already has that bucket name. That's
  unlikely, since the name includes your account number. If it happens, change `project_name`
  in `backend/variables.tf`, **and** change `dynamodb_table` in every `.tfbackend` file to match
  (`<project_name>-terraform-locks`).
- **`No outputs found` when running `init` in `ec2/`**: The backend hasn't been created, or its
  state file was deleted. Go to `terraform/backend` and run `terraform apply`.
- **`Backend configuration changed`** or **`Backend initialization required`**: You switched
  environments without `-reconfigure`. Run the full `init -reconfigure ...` command again.
- **`Error acquiring the state lock`**: Someone (or another terminal) is running Terraform on the
  same environment. Wait for it to finish. If a run crashed and left the lock behind, run
  `terraform force-unlock <LOCK_ID>` with the ID shown in the error. Only do this when you're
  sure nothing else is running.
- **A warning that `dynamodb_table` is deprecated**: Newer Terraform versions (1.11+) can lock
  with S3 alone (`use_lockfile = true`). It's only a warning: DynamoDB locking still works, and
  it's what most existing teams use today.
- **`Your query returned no results`** on `data.aws_ami.selected`: No AMI matches your
  `ami_name_filter` and `ami_owners`. Check the pattern for typos, and make sure the owner
  matches the image (`amazon` for Amazon Linux, `099720109477` for Ubuntu).
- **`The architecture 'arm64' of the specified instance type does not match`** (or the other
  way round): The AMI and instance type are for different chip types. `x86_64` images need
  `t3.*`; `arm64` images need `t4g.*`.
- **`environment must be one of: dev, qa, prod`**: You forgot `-var-file=...` or used a name
  that isn't allowed.
- **SSH times out**: Your IP changed since the last `apply`, or you're on a VPN. Run `apply`
  again so the rule picks up your current IP, and compare `ssh_allowed_cidrs` with
  `curl https://checkip.amazonaws.com`.
- **`Could not look up your public IP`**: Terraform couldn't reach checkip.amazonaws.com. Set
  `allow_my_ip = false` and put your IP in `allowed_ssh_cidrs` by hand.
- **`SSH key not found`** (during `plan`): The `.pem` or `.pem.pub` file for this environment
  doesn't exist at `ssh_private_key_path`. Run the `ssh-keygen` command from Part 4.
- **`Permission denied (publickey)`**: Use the user that matches the image (`ec2-user` for Amazon
  Linux, `ubuntu` for Ubuntu), and point `-i` at the `.pem` file from `ssh_private_key_path`.
  If you made a new key after the server was built, see "Rotating a key" in Part 4.
- **`UNPROTECTED PRIVATE KEY FILE`**: The `.pem` file's permissions were changed. Run
  `chmod 400 ~/.ssh/zero2ai-ec2-dev.pem`.
- **You can't see your resources in the Console**: Switch the region (top-right corner) to
  **US East (N. Virginia)**.

---

## What you just learned

- **Modules** let you write infrastructure once and reuse it. Outputs from one module can feed
  inputs of another.
- A **remote backend** keeps Terraform's **state** in an **S3 bucket**: versioned, encrypted,
  private, and shared.
- A **DynamoDB lock table** stops two runs from changing the same environment at the same time.
- **dev, qa, and prod** can share one codebase. Only the `.tfvars` (settings) and `.tfbackend`
  (state location) files differ.
- `terraform init -reconfigure -backend-config=...` switches which environment you're working on.
- The **AMI is chosen dynamically** with a `data "aws_ami"` lookup driven by variables in
  `variables.tf`, so changing the operating system is a settings change, not a code change.
- `default_tags` label every resource with its environment and owner automatically.
- And as always: **`terraform destroy`** each environment when you're done.

## Where to next

[Chapter 09 — A robot helper that checks your work (CI/CD)](../chapter-09-cicd). You'll get
a free robot helper to check your code every time you save it to GitHub. Later, in
[Chapter 10](../chapter-10-kubernetes), you'll come back to this Terraform layout.
