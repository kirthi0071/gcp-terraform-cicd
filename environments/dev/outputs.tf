output "vpc_id" {
  value = module.vpc.vpc_id
}

output "subnet_id" {
  value = module.vpc.subnet_id
}

output "vm_name" {
  value = module.vm.vm_name
}

output "vm_external_ip" {
  value = module.vm.vm_external_ip
}