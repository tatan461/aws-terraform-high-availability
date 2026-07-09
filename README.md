# Automated High-Availability Web Infrastructure on AWS with Terraform

This project uses Terraform to deploy a highly available web infrastructure on AWS.

The goal was to build a resilient setup across multiple Availability Zones using core AWS networking, load balancing, and auto scaling services, while keeping the architecture simple enough for learning, testing, and cost control.

## Architecture Overview

The configuration provisions a web infrastructure from scratch using AWS resources defined in Terraform.

Main components include:

- **Custom VPC:** A dedicated network environment for the project.
- **Public subnets across multiple Availability Zones:** Used to distribute infrastructure across more than one AZ and reduce single points of failure.
- **Application Load Balancer (ALB):** Accepts HTTP traffic and routes requests to healthy backend instances.
- **Auto Scaling Group (ASG):** Maintains the desired number of EC2 instances and replaces unhealthy instances automatically.
- **Security Groups:** Restrict traffic between components and control inbound access.
- **EC2 user data bootstrapping:** Installs and starts Apache automatically during instance launch.

## Project Highlights

This project was built to practice core infrastructure concepts such as:

- Infrastructure as Code with Terraform
- AWS networking with VPC and subnets
- High availability across multiple Availability Zones
- Load balancing with ALB
- Elastic compute capacity with Auto Scaling
- Basic troubleshooting of cloud networking and instance bootstrapping

## Challenges and Troubleshooting

### Instance type and AMI compatibility

The initial deployment used a different instance family, but the target account and region setup required an adjustment. The configuration was updated to use `t4g.micro`, and the AMI selection logic was changed to use an `arm64` image compatible with AWS Graviton instances.

### Resolving load balancer health check failures

During testing, the load balancer returned unhealthy targets and application errors. Troubleshooting showed that the EC2 instances could not complete package installation during boot without outbound internet access, so the design was adjusted to allow successful initialization without introducing extra NAT Gateway cost. The `user_data` script was also corrected after identifying a heredoc formatting issue that prevented the bootstrap commands from executing as expected.

## Prerequisites

Before deployment, make sure the following tools are installed and configured:

- AWS CLI
- Terraform CLI
- Valid AWS credentials with permission to create networking, EC2, and load balancing resources

## Deployment

Initialize the working directory:

```bash
terraform init
```

Review the execution plan:

```bash
terraform plan
```

Apply the infrastructure:

```bash
terraform apply
```

It is also a good practice to format and validate the configuration before applying changes:

```bash
terraform fmt
terraform validate
```

## Repository Files

- `main.tf` – Main infrastructure resources
- `providers.tf` – AWS provider configuration
- `variables.tf` – Input variables used by the deployment

## Notes

This project focuses on the infrastructure layer and was created as a hands-on Terraform and AWS practice project. Future improvements could include remote state management, reusable modules, private application subnets with NAT, and a database tier.

