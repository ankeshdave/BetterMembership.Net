param($installPath, $toolsPath, $package, $project)

try {
	$projectPath = split-path $project.FullName -parent
	$files = get-childitem $projectPath *Controller.cs -rec
	if ($files)
	{
		foreach ($file in $files)
		{
			$content = (Get-Content $file.PSPath)
			if ($content -match "\[InitializeSimpleMembership\]")
			{
				$content = ($content -join "`r`n") -replace "\s+\[InitializeSimpleMembership\]", ""
				Set-Content $file.PSPath $content 
			}
		}
	}

    $timestamp = (Get-Date).ToString('yyyyMMddHHmmss')
    $projectName = [IO.Path]::GetFileName($project.ProjectName.Trim([IO.PATH]::DirectorySeparatorChar, [IO.PATH]::AltDirectorySeparatorChar))
    $catalogName = "aspnet-$projectName-$timestamp"
    $connectionString ="Data Source=(LocalDb)\v11.0;Initial Catalog=$catalogName;Integrated Security=SSPI;AttachDBFilename=|DataDirectory|\$catalogName.mdf"
    $connectionStringToken = 'Data Source=(LocalDb)\v11.0;'
    $config = $project.ProjectItems | Where-Object { $_.Name -eq "Web.config" }    
    $configPath = ($config.Properties | Where-Object { $_.Name -eq "FullPath" }).Value
    
    $xml = New-Object System.Xml.XmlDocument
    $xml.Load($configPath)
	
	$node = $xml.SelectSingleNode("/configuration/system.web/roleManager")
	$node.SetAttribute("enabled", "true")
	$node.SetAttribute("defaultProvider", "BetterProvider")

	$node = $xml.SelectSingleNode("/configuration/system.web/profile")
	$node.SetAttribute("enabled", "true")
	$node.SetAttribute("defaultProvider", "BetterProvider")
	
	$node = $xml.SelectSingleNode("/configuration/system.web/membership")
	$node.SetAttribute("defaultProvider", "BetterProvider")
    
    $connectionStrings = $xml.SelectSingleNode("/configuration/connectionStrings")
    if (!$connectionStrings) {
        $connectionStrings = $xml.CreateElement("connectionStrings")
        $xml.configuration.AppendChild($connectionStrings) | Out-Null
    }
    
    if (!($connectionStrings.SelectNodes("add[@name='DefaultConnection']") | Where { $_.connectionString.StartsWith($connectionStringToken, 'OrdinalIgnoreCase') })) {
        $newConnectionNode = $xml.CreateElement("add")
        $newConnectionNode.SetAttribute("name", 'DefaultConnection')
        $newConnectionNode.SetAttribute("providerName", "System.Data.SqlClient")
        $newConnectionNode.SetAttribute("connectionString", $connectionString)
        
        $connectionStrings.AppendChild($newConnectionNode) | Out-Null
    }
    
    $xml.Save($configPath)
    
} catch [Exception] {
    Write-Error "Unable to update the web.config file at $configPath. Add the following connection string to your config: <add name=`"DefaultConnection`" providerName=`"System.Data.SqlClient`" connectionString=`"$connectionString`" />"
}