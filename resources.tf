resource "azurerm_resource_group" "romlab-rg" {
  location = var.location
  name     = "alb-demo-rg"
  tags     = var.default_tags
}

resource "azurerm_network_security_group" "romlab-privnetsg" {
  location            = var.location
  name                = "vm-privnet-sg"
  resource_group_name = azurerm_resource_group.romlab-rg.name

  security_rule {
    name                         = "AllowRDP"
    description                  = "To be able to remotely connect to VMs"
    source_address_prefix        = "71.183.150.118/32"
    source_port_range            = "*"
    protocol                     = "Tcp"
    destination_port_range       = "3389"
    destination_address_prefixes = var.vm_address_prefixes
    direction                    = "Inbound"
    priority                     = 500
    access                       = "Allow"
  }
  tags = var.default_tags
}

resource "azurerm_network_interface_security_group_association" "romlab-privnetsg-assoc" {
  count = length(azurerm_network_interface.romlab-web-vmnic)

  network_interface_id      = azurerm_network_interface.romlab-web-vmnic[count.index].id
  network_security_group_id = azurerm_network_security_group.romlab-privnetsg.id
}

resource "azurerm_network_security_rule" "romlab_sgrule_allowwinrm" {
  name                         = "AllowWinRM"
  priority                     = 200
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "5986"
  source_address_prefix        = "71.183.150.118/32"
  destination_address_prefixes = var.vm_address_prefixes
  network_security_group_name  = azurerm_network_security_group.romlab-privnetsg.name
  resource_group_name          = azurerm_resource_group.romlab-rg.name
}

resource "azurerm_virtual_network" "romlab-vnet" {
  address_space       = ["10.253.0.0/16"]
  location            = var.location
  name                = "alb-demo-vnet"
  resource_group_name = azurerm_resource_group.romlab-rg.name

  tags = var.default_tags
}
resource "azurerm_subnet" "romlab-vm-privnets" {
  count                = 2
  address_prefixes     = [var.vm_address_prefixes[count.index]]
  name                 = "alb-demo-vmprivnet-${count.index + 1}"
  resource_group_name  = azurerm_resource_group.romlab-rg.name
  virtual_network_name = azurerm_virtual_network.romlab-vnet.name
}

resource "azurerm_subnet" "romlab-alb-pubnet" {
  count                = length(var.vm_address_prefixes)
  address_prefixes     = ["10.253.10.0/24"]
  name                 = "alb-demo-albpubnet"
  resource_group_name  = azurerm_resource_group.romlab-rg.name
  virtual_network_name = azurerm_virtual_network.romlab-vnet.name
}

resource "azurerm_public_ip" "romlab-alb-pip" {
  allocation_method   = "Static"
  location            = var.location
  name                = "alb-demo-albpip"
  resource_group_name = azurerm_resource_group.romlab-rg.name

  tags = var.default_tags
}
resource "azurerm_application_gateway" "romlab-web-appgw" {
  location            = var.location
  name                = "alb-demo-appgw"
  resource_group_name = azurerm_resource_group.romlab-rg.name
  depends_on          = [azurerm_subnet.romlab-alb-pubnet]
  sku {
    name     = "Basic"
    tier     = "Basic"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "alb-demo-appgw-privip"
    subnet_id = azurerm_subnet.romlab-alb-pubnet[0].id
  }
  frontend_port {
    name = "alb-frontendport"
    port = 80
  }
  frontend_ip_configuration {
    name                 = "alb-frontend-pip"
    public_ip_address_id = azurerm_public_ip.romlab-alb-pip.id
  }
  backend_address_pool {
    name = "webvm-backend"
    ip_addresses = [
      azurerm_network_interface.romlab-web-vmnic[0].ip_configuration[0].private_ip_address,
      azurerm_network_interface.romlab-web-vmnic[1].ip_configuration[0].private_ip_address
    ]
  }
  backend_http_settings {
    cookie_based_affinity = "Disabled"
    name                  = "alb-be-http"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 20
  }
  request_routing_rule {
    name                       = "alb-routerule"
    rule_type                  = "Basic"
    http_listener_name         = "alb-httplisten"
    backend_address_pool_name  = "webvm-backend"
    backend_http_settings_name = "alb-be-http"
    priority                   = "1"
  }
  http_listener {
    name                           = "alb-httplisten"
    frontend_ip_configuration_name = "alb-frontend-pip"
    frontend_port_name             = "alb-frontendport"
    protocol                       = "Http"
  }
  tags = var.default_tags
}

resource "azurerm_network_interface" "romlab-web-vmnic" {
  count               = 2
  location            = var.location
  name                = "${var.vmname-prefix}-${format("%02d", count.index + 1)}"
  resource_group_name = azurerm_resource_group.romlab-rg.name


  ip_configuration {
    name                          = "${var.vmname-prefix}-privip-${format("%02d", count.index + 1)}"
    subnet_id                     = element(azurerm_subnet.romlab-vm-privnets.*.id, count.index)
    private_ip_address_allocation = "Static"
    private_ip_address            = element(var.vm_priv_ips, count.index)
  }
  tags = var.default_tags
}

resource "azurerm_virtual_machine" "romlab-web-vm" {
  count                         = 2
  location                      = var.location
  name                          = "${var.vmname-prefix}-${format("%02d", count.index + 1)}"
  network_interface_ids         = [azurerm_network_interface.romlab-web-vmnic[count.index].id]
  resource_group_name           = azurerm_resource_group.romlab-rg.name
  vm_size                       = "Standard_B1ms"
  zones                         = [var.vm_zones[count.index]] # Assign the VM to the correct zone
  delete_os_disk_on_termination = true
  storage_os_disk {
    name              = "${var.vmname-prefix}-osdisk-${format("%02d", count.index + 1)}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
    disk_size_gb      = 250
  }
  os_profile {
    computer_name  = "${var.vmname-prefix}-${format("%02d", count.index + 1)}"
    admin_username = var.vm-admin
    admin_password = var.vm-admin-pw
  }
  os_profile_windows_config {
    enable_automatic_upgrades = "true"
    provision_vm_agent        = true
    timezone                  = "Eastern Standard Time"
  }
  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
  tags = var.default_tags
}

resource "null_resource" "ansible_playbook" {
  provisioner "local-exec" {
    command = <<EOT
wsl ansible-playbook -i '/mnt/c/Users/Chris Romulus/OneDrive/Documents/RomulusLab/Ansible/Romlab-azagw-azvmweb/az-alb-webserver.ini' '/mnt/c/Users/Chris Romulus/OneDrive/Documents/RomulusLab/Ansible/Romlab-azagw-azvmweb/setup_winrm.yml'
EOT
  }

  depends_on = [azurerm_virtual_machine.romlab-web-vm]
}
