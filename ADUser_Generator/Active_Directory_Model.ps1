# Bruno Gomes
# Populate AD
##############

$ADDomain = Get-ADDomain
$Root = $ADDomain.DistinguishedName 
$OUCompany = "AD-"+$ADDomain.NetBIOSName
$OU = "OU="+$OUCompany+","+$ADDomain.DistinguishedName
New-ADOrganizationalUnit -Name $OUCompany -Path $Root -ProtectedFromAccidentalDeletion $False

$departments = @(
    [pscustomobject]@{"Name" = "Contabilidade"; Positions = ("Gerente", "Contador", "Escrituração", "Gerente de Auditoria Interna", "Gerente de Contabilidade", "Auxiliar de Contabilidade", "Contador Gerencial", "Consultor Fiscal", "Assistente de Contabilidade") },
    [pscustomobject]@{"Name" = "Consultoria"; Positions = ("Gerente", "Administrador", "Consultoria de Finanças", "Consultoria de Marketing", "Estruturação") },
    [pscustomobject]@{"Name" = "Atendimento ao cliente"; Positions = ("Gestor de Atendimento ao Cliente", "Atendimento Pleno", "Atendimento Junior", "Assistente de Atendimento ao Cliente", "Treinador", "Call Center", "Representantes de suporte ao cliente") },
[pscustomobject]@{"Name" = "Engenharia"; Positions = ("Gerente", "Engenheiro Nível 1", "Engenheiro Nível 2", "Engenheiro Nível 3")},
[pscustomobject]@{"Name" = "Executivo"; Positions = ("Executivo", "Assistente Executivo","Assistente Executivo","Auxiliar Executivo")},
    [pscustomobject]@{"Name" = "Financeiro"; Positions = ("Gerente", "Assessor Financeiro", "Estagiário Financeiro", "Faturamento", "Cobranças", "Assistente de Faturamento", "Assistente de Cobranças", "Auxiliar Financeiro") },
    [pscustomobject]@{"Name" = "Recursos Humanos"; Positions = ("Gerente", "Recrutamento e Seleção", "Departamento Pessoal", "Treinamento e Desenvolvimento", "Consultoria de Recursos Humanos", "Departamento Pessoal", "Assistente Departamento Pessoal", "Auxiliar Departamento Pessoal") },
    [pscustomobject]@{"Name" = "Fabricação"; Positions = ("Gerente", "Setor Primário", "Auxiliar Setor Primário", "Operador de Manufatura I", "Operador de Manufatura II", "Fabricação Nível 2", "Fabricação Nível 3") },
    [pscustomobject]@{"Name" = "Marketing"; Positions = ("Gerente", "Especialista em Mídia Social", "Líder da Comunidade", "Marketing Digital", "Assistente de Marketing Digital", "Marketing Interno", "Assistente de Marketing Interno", "Marketing de Conteúdo", "Assistente Marketing de Conteúdo") },
    [pscustomobject]@{"Name" = "Compras"; Positions = ("Gerente", "Assistente de Compras", "Analista de Compras", "Comprador Junior", "Comprador Pleno", "Comprador Sênior", "Pedido") },
    [pscustomobject]@{"Name" = "Qualidade"; Positions = ("Gerente", "Analista de Controle de Qualidade", "Assistente de Controle de Qualidade", "Auxiliar de Controle de Qualidade", "Auditor de Controle de Qualidade", "Consultor de Qualidade", "Coordenador de Qualidade", "Gerente de Controle de Qualidade", "Supervisor de Controle de Qualidade") },
[pscustomobject]@{"Name" = "Vendas"; Positions = ("Gerente", "Representante de Vendas Regional.", "Representante de Vendas Nacional", "Novo Negócio")}
)


$DPaths = @("Computers","Users")
$UC = ","+$OU
$Cidades = @("Joinville","SaoPaulo","Curitiba","Itajai","Miami","Salvador")
$UPNDomain = "@"+(Get-ADDomain).Forest
$Password = 'Pa$$w0rd'
$securePassword = ConvertTo-SecureString -AsPlainText $Password -Force
$departmentIndex = 0

ForEach ($Cidade in $Cidades) {
    
    New-ADOrganizationalUnit -Name $Cidade -Path $OU

    ForEach ($Department in $Departments) {
        $OUCidade = "OU="+$Cidade+","+$OU
        $departmentIndex = Get-Random -Minimum 0 -Maximum $departments.Count
        $company = (Get-ADDomain).NetBIOSName + " - " +$Cidade

        New-ADOrganizationalUnit -Name $Department.name -Path $OUCidade
        
        ForEach ($DPath in $DPaths) {
            $DepName = $Department.name
            $OUDPath = "OU="+"$DepName"+","+"OU="+$Cidade+","+$OU
            New-ADOrganizationalUnit -Name $DPath -Path $OUDPath

            $i = Get-Random -Minimum 5 -Maximum 35
            $usercount = 1
            
            if ($i -le $usercount ) {break}
            if ($DPath -eq "Users") {

                $OUUser = "OU=Users,"+$OUDPath
                $OUAGroups = "OU=Groups,"+$OUCidade
                $FirstNames = (Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/BrunoPolezaGomes/Active-Directory-Windows-Terraform//main/ADUser_Generator/FirstNames.csv").content | ConvertFrom-Csv -Delim ',' -Header 'FirstName'  
                $LastNames  = (Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/BrunoPolezaGomes/Active-Directory-Windows-Terraform//main/ADUser_Generator/LastNames.csv").content | ConvertFrom-Csv -Delim ',' -Header 'LastName'
                $CSV_Fname = New-Object System.Collections.ArrayList
                $CSV_Lname = New-Object System.Collections.ArrayList
                $CSV_Fname.Add($FirstNames)
                $CSV_Lname.Add($LastNames)

            ForEach ($FirstName in $FirstNames) {
                    foreach ($LastName in $LastNames) {
                    if ($i -le $usercount ) {break}
                    $First = ($CSV_Fname | Get-Random).FirstName
                    $Last = ($CSV_Lname | Get-Random).LastName
                    $Fname = (Get-Culture).TextInfo.ToTitleCase($First)
                    $LName = (Get-Culture).TextInfo.ToTitleCase($Last)
                    $displayName = (Get-Culture).TextInfo.ToTitleCase($Fname + " " + $Lname)
                    
                    [string]$firstletter = $Fname.ToLower()
                    [string]$sAMAccountName = $firstletter + "." + "$($firstletter.Substring($firstletter.Length-1))" + $LName.ToLower().split(" ")[0].replace("'", "")
                    $userExists = $false
                    
                    $sAMAccountName


                    $title = $departments[$departmentIndex].Positions[$(Get-Random -Minimum 0 -Maximum $departments[$departmentIndex].Positions.Count)]
                    
                    $pn2 = Get-Random -Minimum 8990 -Maximum 9999
                    $pn3 = "{0:0000}" -f  (Get-Random -Minimum 5000 -Maximum 9995)
                    $areacode = 47, 11, 21, 49, 53, 13 | Get-Random
                    $phonenumber = "($areacode) $pn2-$pn3"
                    $Description = $title
                    $Office = $company

        $GroupName = $Cidade + " - "+ $Department.name
        $SamaGroup = "$($Cidade.ToLower()).$($Department.name.ToLower())"
        
        try {New-ADOrganizationalUnit -Name "Groups" -Path $OUCidade}
        catch{}
        try {New-ADGroup -Name $GroupName -SamAccountName $SamAGroup -GroupCategory Security -GroupScope Global -DisplayName $GroupName -Path $OUAGroups}
        catch{}
    
                        New-ADUser -AccountPassword $securePassword -Company $company -Department $department.Name -DisplayName $displayName -EmailAddress "$($sAMAccountName)$($UPNDomain)" -Enabled $True -GivenName $Fname -Name $displayName -OfficePhone $phonenumber -Path $OUUser -SamAccountName $sAMAccountName -Surname $Lname -Title $title -Description $Description -Office $Office -UserPrincipalName "$($sAMAccountName)$($UPNDomain)"

                        Set-ADUser -Identity $sAMAccountName -Add @{'proxyAddresses' = "SMTP:$($sAMAccountName)$($UPNDomain)" }

    #Write-Host "$UserCount de $i    --   $displayName  -  $($sAMAccountName)@$($UPNDomain)" -ForegroundColor Green
    Add-ADGroupMember -Identity $SamaGroup -Members $sAMAccountName
                        $UserCount += 1
                        
                        }
                      
                    }
                   
                }      
             
            }
        }
        $departmentIndex += 1
    }



