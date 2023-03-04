## Provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "random_string" "int" {
    length  = 2
    upper   = false
    lower   = false
    number  = true
    special = false
}

## Create the Resource Group
resource "azurerm_resource_group" "rg" {
    name     = "RG-${var.resource_group_name["name"]}"
    location = var.resource_group_name["location"]
    tags     = var.tags
}

#data "azurerm_resource_group" "rg" {
#  name                = "RG-${var.resource_group_name["name"]}"
#  #resource_group_name = "${azurerm_virtual_machine.VM.resource_group_name}"
#}

## Create the Resource VNet
resource "azurerm_virtual_network" "vnet" {
    name                = "vNET-${var.resource_group_name["name"]}"
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    address_space       = ["10.0.0.0/16"]
    tags                = var.tags
}

## Create the Resource SubNet
resource "azurerm_subnet" "subnet" {
    name                 = "sNet-Local"
    resource_group_name  = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefixes     = ["10.0.2.0/24"]
}

## Create the Resource SNG
resource "azurerm_network_security_group" "nsg" {
    name                = "NSG-${var.resource_group_name["name"]}"
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    tags                = var.tags
}

## Create the Resource Network Rules
resource "azurerm_network_security_rule" "rules" {
    for_each                    = local.nsgrules 
    name                        = each.key
    direction                   = each.value.direction
    access                      = each.value.access
    priority                    = each.value.priority
    protocol                    = each.value.protocol
    source_port_range           = each.value.source_port_range
    destination_port_range      = each.value.destination_port_range
    source_address_prefix       = each.value.source_address_prefix
    destination_address_prefix  = each.value.destination_address_prefix
    resource_group_name         = azurerm_resource_group.rg.name
    network_security_group_name = azurerm_network_security_group.nsg.name
}

## Associate VM NSG with the subnet
resource "azurerm_subnet_network_security_group_association" "VM-nsg-association" {
    depends_on=[azurerm_resource_group.rg]
    subnet_id                 = azurerm_subnet.subnet.id
    network_security_group_id = azurerm_network_security_group.nsg.id
}

## Get a Static Public IP
resource "azurerm_public_ip" "VM-ip" {
    depends_on=[azurerm_resource_group.rg] 
    name                = "IP-${random_string.int.result}${var.VirtualMachine["VM_Name"]}"
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    allocation_method   = "Dynamic"
    tags                = var.tags
}

## Create Network Card for linux VM
resource "azurerm_network_interface" "VM-nic" {
    depends_on = [azurerm_resource_group.rg]
    name                = "NIC-${random_string.int.result}${var.VirtualMachine["VM_Name"]}"
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    tags                = var.tags
  ip_configuration {
        name                          = "internal"
        subnet_id                     = azurerm_subnet.subnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.VM-ip.id
        }
}

resource "azurerm_windows_virtual_machine" "ADDC" {
    name                    = var.VirtualMachine["VM_Name"]
    computer_name           = var.VirtualMachine["VM_Name"]
    location                = azurerm_resource_group.rg.location
    resource_group_name     = azurerm_resource_group.rg.name 
    size                    = var.VirtualMachine["size"]
    admin_username          = var.VirtualMachine["admin_username"]
    admin_password          = var.VirtualMachine["admin_password"]
    license_type            = "Windows_Server"
    network_interface_ids   = [azurerm_network_interface.VM-nic.id]

os_disk {
    name                    = "DISK-${random_string.int.result}${var.VirtualMachine["VM_Name"]}"
    caching                 = "ReadWrite"
    storage_account_type    = "Standard_LRS"
    }


  source_image_reference {
    publisher               = var.VirtualMachine["publisher"]
    offer                   = var.VirtualMachine["offer"]
    sku                     = var.VirtualMachine["sku"]
    version                 = var.VirtualMachine["version"]
  }

  enable_automatic_updates  = true
  provision_vm_agent        = true
}

locals {
  dc1_fqdn = "${var.VirtualMachine["VM_Name"]}.${var.VirtualMachine["ad_domain_name"]}"
  
  dc1_prereq_ad_1 = "Import-Module ServerManager"
  dc1_prereq_ad_2 = "Install-WindowsFeature AD-Domain-Services -IncludeAllSubFeature -IncludeManagementTools"
  dc1_prereq_ad_3 = "Install-WindowsFeature DNS -IncludeAllSubFeature -IncludeManagementTools"
  dc1_prereq_ad_4 = "Import-Module ADDSDeployment"
  dc1_prereq_ad_5 = "Import-Module DnsServer"

  dc1_install_ad_1         = "Install-ADDSForest -DomainName ${var.VirtualMachine["ad_domain_name"]} -DomainNetbiosName ${var.VirtualMachine["ad_domain_netbios_name"]} -DomainMode ${var.VirtualMachine["ad_domain_mode"]} -ForestMode ${var.VirtualMachine["ad_domain_mode"]} "
  dc1_install_ad_2         = "-DatabasePath ${var.VirtualMachine["ad_database_path"]} -SysvolPath ${var.VirtualMachine.ad_sysvol_path} -LogPath ${var.VirtualMachine.ad_log_path} -NoRebootOnCompletion:$false -Force:$true "
  dc1_install_ad_3         = "-SafeModeAdministratorPassword (ConvertTo-SecureString ${var.VirtualMachine["ad_safe_mode_administrator_password"]} -AsPlainText -Force)"

  dc1_shutdown_command     = "shutdown -r -t 10"
  dc1_exit_code_hack       = "exit 0"

  dc1_powershell_command   = "${local.dc1_prereq_ad_1}; ${local.dc1_prereq_ad_2}; ${local.dc1_prereq_ad_3}; ${local.dc1_prereq_ad_4}; ${local.dc1_prereq_ad_5}; ${local.dc1_install_ad_1}${local.dc1_install_ad_2}${local.dc1_install_ad_3};${local.dc1_populate_ad_1}; ${local.dc1_populate_ad_2}; ${local.dc1_shutdown_command}; ${local.dc1_exit_code_hack}"

dc1_populate_ad_1 = "$URL = 'https://raw.githubusercontent.com/BrunoPolezaGomes/Active-Directory-Windows-Terraform//main/ADUser_Generator/Active_Directory_Model.ps1'"
dc1_populate_ad_2 = "$req = [System.Net.WebRequest]::Create($URL); $res = $req.GetResponse(); iex ([System.IO.StreamReader] ($res.GetResponseStream())).ReadToEnd()"
dc1_powershell_adpopulate  = "${local.dc1_populate_ad_1}; ${local.dc1_populate_ad_2}"
    

}

resource "azurerm_virtual_machine_extension" "dc1-vm-extension" {
  depends_on=[azurerm_windows_virtual_machine.ADDC]

    name                 = "${var.VirtualMachine["VM_Name"]}-Install-Active-Directory"
    virtual_machine_id   = azurerm_windows_virtual_machine.ADDC.id
    publisher            = "Microsoft.Compute"
    type                 = "CustomScriptExtension"
    type_handler_version = "1.9"  
    settings = <<SETTINGS
    {
    "commandToExecute": "powershell.exe -Command \"${local.dc1_powershell_command}\""
    }
    SETTINGS
}


#resource "azurerm_virtual_machine_extension" "populate_ad_server" {
#  depends_on=[azurerm_windows_virtual_machine.ADDC]
#
#    name                 = "${var.VirtualMachine["VM_Name"]}-Populate-AD-Server"
#    virtual_machine_id   = azurerm_windows_virtual_machine.ADDC.id
#    publisher            = "Microsoft.Compute"
#    type                 = "CustomScriptExtension"
#    type_handler_version = "1.9"
#    settings = <<SETTINGS
#    {
#    "commandToExecute": "powershell.exe -Command \"${local.dc1_powershell_adpopulate}\""
#    }
#    SETTINGS
#  
#}
#
resource "null_resource" "previous" {}
resource "time_sleep" "wait_30_seconds" {
  depends_on = [null_resource.previous]
  create_duration = "420s"
}
resource "null_resource" "next" {
  depends_on = [time_sleep.wait_30_seconds]
}