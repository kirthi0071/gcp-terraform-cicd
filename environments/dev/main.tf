module "vpc" {
  source = "../../modules/vpc"

  vpc_name    = var.vpc_name
  region      = var.region
  subnet_cidr = var.subnet_cidr
}

module "firewall" {
  source = "../../modules/firewall-rules"

  vpc_name       = var.vpc_name
  vpc_self_link  = module.vpc.vpc_self_link
  subnet_cidr    = var.subnet_cidr
  ssh_source_ranges = ["103.6.157.201/32"]
}

module "vm" {
  source = "../../modules/vm"

  vm_name           = var.vm_name
  machine_type      = var.machine_type
  zone              = var.zone
  subnet_self_link  = module.vpc.subnet_self_link
  environment       = "dev"

  depends_on = [module.firewall]
}
