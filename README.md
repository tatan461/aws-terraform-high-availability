# AWS High-Availability Web Infrastructure

An infrastructure-as-code project using modular Terraform to deploy a highly available, multi-AZ web server topology on AWS. 

The main goal of this architecture is to separate public-facing entry points from the backend application tier, ensuring that web instances remain isolated from direct internet access.

## Architecture

This setup provisions a complete network and compute stack from scratch:

*   **VPC Topology:** A custom VPC spanning two Availability Zones. It isolates traffic into public and private subnet pairs.
*   **Ingress Control:** An Application Load Balancer (ALB) sits in the public subnets to distribute incoming HTTP traffic.
*   **Auto Scaling:** An Auto Scaling Group (ASG) manages EC2 instances inside the private subnets. It scales between 2 and 4 instances based on demand.
*   **Strict Security Groups:** The private web instances do not accept traffic from the internet. Their security group only allows inbound traffic originating from the ALB's security group.
*   **Cost Optimization:** Instances run on AWS Graviton (`t4g.micro`) ARM64 architecture, lowering baseline computing costs compared to standard x86 instances.

## Repository Structure

The configuration is modularized to separate core networking from application logic:

```text
├── main.tf                 # Global orchestration file mapping module dependencies
├── providers.tf            # AWS provider definition
├── variables.tf            # Top-level input variables
├── outputs.tf              # Returns the live ALB DNS endpoint
└── modules/
    ├── vpc/                # Subnets, Internet Gateway, and Route Tables
    ├── alb/                # Load Balancer, Listener, and Target Group
    └── compute/            # Security Groups, Launch Template, and ASG
```

## How to Run It

### Prerequisites
*   AWS CLI configured with valid credentials.
*   Terraform CLI installed (`>= 1.5.0`).

### Deployment Steps
1. Initialize the working directory and download module dependencies:
   ```bash
   terraform init
   ```

2. Format and validate the configuration files:
   ```bash
   terraform fmt -recursive
   terraform validate
   ```

3. Review the execution plan to see what resources will be created:
   ```bash
   terraform plan
   ```

4. Deploy the infrastructure to AWS:
   ```bash
   terraform apply
   ```

Once completed, the terminal will output the `website_url`. Open it in your browser to verify that the Apache server is responding.

### Clean Up
To remove all provisioned resources and avoid ongoing AWS billing, run:
```bash
terraform destroy
```

## Design Decisions & Trade-offs

*   **No NAT Gateways:** NAT Gateways were deliberately excluded from this configuration to avoid the fixed hourly costs associated with AWS managed NAT gateways on a personal testing account. Compute instances are safely isolated in private subnets, and code updates use the pre-baked software packages.
*   **Dynamic AMI Selection:** Instead of using hardcoded AMI IDs that break over time or across different AWS accounts, the compute module uses a dynamic `aws_ami` data source to fetch the latest stable Amazon Linux 2023 ARM64 image.
