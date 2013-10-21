$scriptPath = (split-path -parent $MyInvocation.MyCommand.Definition)

cls

. "$scriptPath\Initialize.ps1"

#Publish-Mole -Path "C:\Dropbox\Apps\site44\dev.techhike.net"
#Publish-Mole -Path "C:\Dropbox\Apps\site44\dev.techhike.net" -full
#Publish-Mole -Path "C:\Dropbox\Apps\site44\dev.techhike.net" -Preview
Publish-Mole -Path "C:\Dropbox\Apps\site44\www.techhike.net" -PreviewLast
