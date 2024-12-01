# Output the public IP of the application load balancer
output "application_lb_public_ip" {
  value       = azurerm_public_ip.romlab-alb-pip.ip_address
  description = "The public IP address of the application load balancer."
}

# Output the DNS name of the application load balancer
output "application_lb_dns_name" {
  value       = azurerm_public_ip.romlab-alb-pip.fqdn
  description = "The DNS name of the application load balancer."
}

# Output the names of the virtual machines
output "vm_names" {
  value       = [for vm in azurerm_virtual_machine.romlab-web-vm : vm.name]
  description = "The names of the virtual machines."
}

# Output the private IPs of the virtual machines
output "vm_private_ips" {
  value       = [for nic in azurerm_network_interface.romlab-web-vmnic : nic.private_ip_address]
  description = "The private IP addresses assigned to the virtual machines."
}

# Output the availability zones of the virtual machines
output "vm_availability_zones" {
  value       = [for vm in azurerm_virtual_machine.romlab-web-vm : vm.zones]
  description = "The availability zones assigned to the virtual machines."
}