
function Install-Mole(){

    $ModulePath = $Env:PSModulePath -split ";" | Select -Index 0
    $ModulePath = ("{0}\Mole" -f $ModulePath)
	$BaseUrl = 'https://bitbucket.org/TechHike/mole/raw/default/Mole'

	New-Item ($ModulePath + "\Mole\") -ItemType Directory -Force | Out-Null
    Write-Host "Downloading Mole from $BaseUrl"
	

    $Directories = @()
    $Directories += "_mole"
    $Directories += "_mole\Files"
    $Directories += "_mole\Files\images"
    $Directories += "_mole\Pages"
    $Directories += "_mole\Posts"
    $Directories += "_mole\Preview"
    $Directories += "_mole\Templates"
    foreach ($Dir in $Directories) {
        $Dir = ("{0}\{1}" -f $ModulePath, $Dir)
        if (Test-Path $Dir -PathType Container) {
            Write-Host ("Skiping {0}" -f $Dir)
        } else {
            Write-Host ("Creating {0}" -f $Dir)
            New-Item $Dir -Type Directory | Out-Null
        }
    }


    $InstallFiles = @('Mole.psm1', 'Mole.psd1', 'Mole.ps1', 'MarkdownSharp.dll', 'powershellMarkdown.dll')
    $InstallFiles += "_mole\site.ps1"
    $InstallFiles += "_mole\Files\base.css"
    $InstallFiles += "_mole\Files\base.js"
    $InstallFiles += "_mole\Posts\2012-07-15 Welcome.md"
    $InstallFiles += "_mole\Pages\About.md"
    $InstallFiles += "_mole\Pages\404.md"
    $InstallFiles += "_mole\Templates\archive.html"
    $InstallFiles += "_mole\Templates\feed.xml"
    $InstallFiles += "_mole\Templates\feed_post.xml"
    $InstallFiles += "_mole\Templates\main.html"
    $InstallFiles += "_mole\Templates\page.html"
    $InstallFiles += "_mole\Templates\post.html"
    $InstallFiles += "_mole\Templates\topic.html"

    foreach ($File in $InstallFiles) {
        $RemotePath = ("{0}/{1}" -f $BaseUrl, $File)
        $RemotePath = ($RemotePath -replace "\\", "/")
        $LocalPath = ("{0}\{1}" -f $ModulePath, $File)
        Write-Host "Installing $RemotePath"
        #Write-Host "---------- $LocalPath"
        (New-Object Net.WebClient).DownloadFile($RemotePath, $LocalPath)
    }   



    $ExPolicy  = (Get-ExecutionPolicy)

	if ($ExPolicy -eq "Restricted"){
	
        Write-Warning @"
Your execution policy is $executionPolicy, this means you will not be able import or use any scripts including modules.
To fix this change you execution policy to something like RemoteSigned.

        PS> Set-ExecutionPolicy RemoteSigned

For more information execute:
        
        PS> Get-Help about_execution_policies

"@

    } else {
	
		Write-Host "Mole installed." -ForegroundColor Green
        Import-Module Mole
		
    }    
}

Install-Mole