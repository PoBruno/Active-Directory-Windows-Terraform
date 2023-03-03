## "RG-" automatico no main.tf
variable "resource_group_name" {
    type = map(string)
  default = {
    "name"          = "Lab"
    "location"      = "eastus"
    "storage"       = "monga"
 }
}

variable "VirtualMachine" {
  type = map(string)
  default = {
    ## User
    "ad_safe_mode_administrator_password" = "Pa$$w0rd"
    "admin_username"        = "xbox"
    "admin_password"        = "Pa$$w0rd"
    
    ## Active Directory
    ad_domain_name          = "monga.tech"
    ad_domain_netbios_name  = "MONGA"
    ad_database_path        = "C:/Windows/NTDS"
    ad_sysvol_path          = "C:/Windows/SYSVOL"
    ad_log_path             = "C:/Windows/NTDS"
    ad_domain_netbios_name  = "MONGA"
    "ad_domain_mode"        = "WinThreshold"

    ## OS Config
    "VM_Name"               = "ADDCMG01"
    "size"                  = "Standard_B2ms"                       #"Standard_DS3_v2"
    "storage_account_type"  = "Standard_LRS"

    ## Source Image Reference
    "publisher"             = "MicrosoftWindowsServer"                     #"Canonical"
    "offer"                 = "WindowsServer"               #"UbuntuServer"
    "sku"                   = "2022-Datacenter"                     #"20.04-LTS"
    "version"               = "latest"
  }
}

variable "scfile" {
  type      = string
  default   = "linux-vm-docker.bash"
}

variable "tags" {
  type        = map(string)
  default = {
    env         = "Active-Directory",
    rg          = "RG-Monga-lab",
    dept        = "TI",
    costcenter  = "Resource"
  }
}





#############################################
#############################################
###              VM SIZES                 ###
#############################################
### D2as_v4   | CPU 02 | RAM 08 ($ 78.11) ###
### B2ms      | CPU 02 | RAM 04 ($ 66.43) ###
#############################################
### B4ms      | CPU 04 | RAM 16 ($132.86) ###
#############################################
### E4_v5     | CPU 04 | RAM 32 ($205.86) ###
### DS3_v2    | CPU 04 | RAM 14 ($250.39) ###
#############################################
### D8s_v5    | CPU 08 | RAM 32 ($312.44) ###
#############################################
#############################################


