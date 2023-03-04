
terraform {
  required_version = ">=1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "random_string" "int" {
    length  = 3
    upper   = false
    lower   = false
    number  = true
    special = false
}

resource "azurerm_resource_group" "rg" {
  name     = "RG-${var.resource_group_name["name"]}"
  location = var.resource_group_name["location"]
  tags     = var.tags
}

# Create virtual network
resource "azurerm_virtual_network" "my_terraform_network" {
  name                = "vNET-${var.resource_group_name["name"]}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
  tags                = var.tags
}

# Create subnet
resource "azurerm_subnet" "my_terraform_subnet" {
  name                 = "sNet-Local"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.my_terraform_network.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "my_terraform_public_ip" {
  depends_on=[azurerm_resource_group.rg] 
  name                = "IP${random_string.int.result}-${var.VirtualMachine["VM_Name"]}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
  tags                = var.tags
}

# Create Network Security Group and rules
resource "azurerm_network_security_group" "my_terraform_nsg" {
  name                = "NSG-${var.resource_group_name["name"]}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
  security_rule {
    name                       = "RDP"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "web"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create network interface
resource "azurerm_network_interface" "my_terraform_nic" {
  depends_on = [azurerm_resource_group.rg]
  name                = "NIC${random_string.int.result}-${var.VirtualMachine["VM_Name"]}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.my_terraform_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.my_terraform_public_ip.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.my_terraform_nic.id
  network_security_group_id = azurerm_network_security_group.my_terraform_nsg.id
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "my_storage_account" {
  name                      = var.resource_group_name["storage"]
  resource_group_name       = azurerm_resource_group.rg.name
  location                  = azurerm_resource_group.rg.location
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  tags                      = var.tags
}


# Create virtual machine
resource "azurerm_windows_virtual_machine" "main" {
  name                  = var.VirtualMachine["VM_Name"]
  admin_username        = var.VirtualMachine["admin_username"]
  admin_password        = var.VirtualMachine["admin_password"]
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.my_terraform_nic.id]
  size                  = var.VirtualMachine["size"]

  os_disk {
    name                    = "DISK-${random_string.int.result}${var.VirtualMachine["VM_Name"]}"
    caching                 = "ReadWrite"
    storage_account_type    = "Standard_LRS"
  }

  source_image_reference {
    publisher = var.VirtualMachine["publisher"]
    offer     = var.VirtualMachine["offer"]
    sku       = var.VirtualMachine["sku"]
    version   = var.VirtualMachine["version"]
  }


  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.my_storage_account.primary_blob_endpoint
  }
}

locals {
  dc1_fqdn = "${var.VirtualMachine["VM_Name"]}.${var.VirtualMachine["ad_domain_name"]}"
dc1_prereq_ad_1 = "Import-Module ServerManager"
dc1_prereq_ad_2 = "Install-WindowsFeature AD-Domain-Services -IncludeAllSubFeature -IncludeManagementTools"
dc1_prereq_ad_3 = "Install-WindowsFeature DNS -IncludeAllSubFeature -IncludeManagementTools"
dc1_prereq_ad_4 = "Import-Module ADDSDeployment"
dc1_prereq_ad_5 = "Import-Module DnsServer"
dc1_install_ad_1 = "Install-ADDSForest -DomainName ${var.VirtualMachine["ad_domain_name"]} -DomainNetbiosName ${var.VirtualMachine["ad_domain_netbios_name"]} -DomainMode ${var.VirtualMachine["ad_domain_mode"]} -ForestMode ${var.VirtualMachine["ad_domain_mode"]} "
dc1_install_ad_2 = "-DatabasePath ${var.VirtualMachine["ad_database_path"]} -SysvolPath ${var.VirtualMachine.ad_sysvol_path} -LogPath ${var.VirtualMachine.ad_log_path} -NoRebootOnCompletion:$false -Force:$true "
dc1_install_ad_3 = "-SafeModeAdministratorPassword (ConvertTo-SecureString ${var.VirtualMachine["ad_safe_mode_administrator_password"]} -AsPlainText -Force)"
dc1_shutdown_command = "shutdown -r -t 10"
dc1_exit_code_hack = "exit 0"
dc1_populate_ad_1 = "$URL = 'https://raw.githubusercontent.com/BrunoPolezaGomes/Active-Directory-Windows-Terraform//main/ADUser_Generator/Active_Directory_Model.ps1'"
dc1_populate_ad_2 = "$req = [System.Net.WebRequest]::Create($URL); $res = $req.GetResponse(); iex ([System.IO.StreamReader] ($res.GetResponseStream())).ReadToEnd()"
    
dc1_powershell_command  = "${local.dc1_prereq_ad_1}; ${local.dc1_prereq_ad_2}; ${local.dc1_prereq_ad_3}; ${local.dc1_prereq_ad_4}; ${local.dc1_prereq_ad_5}; ${local.dc1_install_ad_1}${local.dc1_install_ad_2}${local.dc1_install_ad_3}; ${local.dc1_shutdown_command}; ${local.dc1_exit_code_hack}"

dc1_powershell_adpopulate  = "${local.dc1_populate_ad_1}; ${local.dc1_populate_ad_2}"

}

# Install IIS web server to the virtual machine
resource "azurerm_virtual_machine_extension" "AD-Install" {
  name                 = "Preparate-AD-Server"
#  resource_group_name  = azurerm_resource_group.main.name
  virtual_machine_id   = azurerm_windows_virtual_machine.main.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

  protected_settings = <<SETTINGS
  {    
    "commandToExecute": "powershell -command \"[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('${base64encode(local.dc1_powershell_command)}')) | Out-File -filepath DomainControllerSetup.ps1\" && powershell -ExecutionPolicy Unrestricted -File DomainControllerSetup.ps1" 
  }
  
  SETTINGS
}

# This resource will create (at least) 30 seconds after null_resource.previous
resource "null_resource" "previous" {}
resource "time_sleep" "wait_30_seconds" {
  depends_on = [null_resource.previous]
  create_duration = "30s"
}
resource "null_resource" "next" {
  depends_on = [time_sleep.wait_30_seconds]
}

resource "azurerm_virtual_machine_extension" "populate_ad_server" {
  name                 = "Populate-AD-Server"
#  resource_group_name  = azurerm_resource_group.main.name
  virtual_machine_id   = azurerm_windows_virtual_machine.main.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

  protected_settings = <<SETTINGS
  {    
    "commandToExecute": "powershell -command \"[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('${base64encode(local.dc1_powershell_adpopulate)}')) | Out-File -filepath DomainControllerPopulate.ps1\" && powershell -ExecutionPolicy Unrestricted -File DomainControllerPopulate.ps1" 
  }
  
  SETTINGS
}

resource "null_resource" "previous1" {}
resource "time_sleep" "wait_30_seconds2" {
  depends_on = [null_resource.previous]
  create_duration = "30s"
}
resource "null_resource" "next1" {
  depends_on = [time_sleep.wait_30_seconds2]
}

















 








