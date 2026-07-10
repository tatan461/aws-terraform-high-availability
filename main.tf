module "vpc" {
  source         = "./modules/vpc"
  environment    = var.environment
  vpc_cidr       = var.vpc_cidr
  public_subnets = var.public_subnets
}

module "alb" {
  source            = "./modules/alb"
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
}

module "compute" {
  source            = "./modules/compute"
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.alb.alb_sg_id
  target_group_arn  = module.alb.target_group_arn
}
