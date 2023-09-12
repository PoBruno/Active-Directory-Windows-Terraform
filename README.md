# Active-Directory-Windows-Terraform
Implanting Windows Server AD populating for Lab


## Populate AD
```PowerShell
$Script = Invoke-WebRequest https://raw.githubusercontent.com/pobruno/Active-Directory-Windows-Terraform/main/ADUser_Generator/Active_Directory_Model.ps1 
Invoke-Expression "$($Script.Content)"
```

