
function Publish-Mole {
    param([string]$Path = ".", [switch]$Preview, [switch]$ShowIndex, [switch]$ShowLast, [switch]$Full, [switch]$Continuous, [switch]$Log)

    $cont = (Initialize -Path $Path)
    if (-not $cont) { return }

    $script:state.preview = $Preview.IsPresent
    $script:state.show_index = $ShowIndex.IsPresent
    $script:state.show_last = $ShowLast.IsPresent
    $script:state.full = $Full.IsPresent
    $script:state.log = $Log.IsPresent

    if ($ShowIndex) {
        Log -Category "Initialize" -Message "Show Index"
    } elseif ($ShowLast) {
        Log -Category "Initialize" -Message "Show Last Modified"
    }

    if ($state.preview) {
        $script:state.output_path = ("{0}\{1}" -f $state.working_path, $site.preview_path)
        if (-not (Test-Path $state.output_path)) {
            New-Item -ItemType directory -Path $state.output_path | Out-Null
        }
    }
    Log -Category "Initialize" -Message ("output_path = {0}" -f $state.output_path)

    if ($Continuous) {

        $last_pass = (Get-Date)
        Log -Category "System" -Message "Waiting..."
        while ($true) {
            $mod_files = (Get-ChildItem -Path ("{0}\*" -f $state.working_path) -Include *.md -Recurse | Where-Object { $_.LastWriteTime -gt $last_pass}).count

            if ($mod_files -gt 0) {
                PreformPass
                Log -Category "System" -Message "Waiting..."
            }

            $last_pass = (Get-Date)
            Start-Sleep -Seconds 1
            #Write-Host "." -NoNewLine
        }

    } else {
        PreformPass
    }
}


function PreformPass {
    Sync
    Clean
    Publish
    Show
    Finalize
}


function Show {
    if ($state.show_last) {
        $lpost = ($state.posts | Where-Object { $state.preview -or ($_.published -and $_.date -lt $now) } | Sort-Object { $_.updated } -Descending | Select-Object -First 1)
        $lpage = ($state.pages | Where-Object { $state.preview -or ($_.published) } | Sort-Object { $_.updated } -Descending | Select-Object -First 1)

        if ($lpost.updated -ge $lpage.updated) {
            Log -Category "Show" -Message $lpost.filepath
            Invoke-Item $lpost.filepath
        } else {
            Log -Category "Show" -Message $lpage.filepath
            Invoke-Item $lpage.filepath
        }
    } elseif ($state.show_index) {
        Invoke-Item ("{0}\index.html" -f $state.output_path)
    }
}


function Initialize-Mole {
    param([string]$Path = ".")

    $sourcePath = ("{0}\_mole" -f $PSScriptRoot)
    $destinationPath = ("{0}\_mole" -f $Path)
    Copy-Item -Path $sourcePath -Destination $destinationPath -Recurse -Force
    Publish-Mole -Full -Preview -ShowIndex -Path $Path
}


# -----------------------------------------------------------

function Initialize {
    param([string]$Path)

    $script:start_time = (Get-Date)
    $script:state = @{}

    $script:state.working_path = (Expand-Path -Path ("{0}\_mole" -f $Path))
    $script:state.state_path = ("{0}\State.json" -f $script:state.working_path)


    $site_config_path = ("{0}\Site.ps1" -f $script:state.working_path)

    if (-not (Test-Path $site_config_path)) {
        Log -Category "System" -Message ("{0} not found." -f $site_config_path) -Color Red
        return $false
    }

    # if (Test-Path $state.state_path) {
    #     write-host $script:state.state_path
    #     write-host (Get-Content -Path $script:state.state_path)
    #     $script:state = (Get-Content -Path $script:state.state_path | ConvertFrom-JSON)
    #     write-host ($state | ConvertTo-JSON)
    #     return $true
    # }

    . $site_config_path

    $script:now = (Get-Date)

    $script:state.root_path = (Expand-Path -Path $Path)
    $script:state.files_path = ("{0}\files" -f $script:state.working_path)
    
	$script:state.template_path = ("{0}" -f $state.working_path, $site.template_path)
    $script:state.template_base_path = ("{0}\TemplateBase.cs" -f $script:state.template_path)

    $script:state.log_filepath = ("{0}\Log_{1:yyyy-MM-dd}.log" -f $state.working_path, $now)

    $script:state.templates  = @{}
    $script:state.template = (Get-Template -Name $site.template)

    $script:state.output_path = $state.root_path
	
    Log -Category "Initialize" -Message "Build Template"
	Initialize-Template

    return $true
}


function Clean {
    $files = (Get-ChildItem -Path ("{0}\*.html" -f $state.output_path))

    foreach ($file in $files) {

        if (@("index.html", "archive.html", "topics.html", "blog.html", "feed.xml") -contains $file.Name) {
            continue
        }

        $exists = ($state.posts | Where-Object { $_.filename -eq $file.Name } | Select-Object -First 1)

        if ($exists.filename -ne $file.Name) {
            $exists = ($state.pages | Where-Object { $_.filename -eq $file.Name } | Select-Object -First 1)
        }

        if ($exists.filename -ne $file.Name) {
            $exists = ($state.topics | Where-Object { $_.filename -eq $file.Name } | Select-Object -First 1)
        }

        if ($exists.filename -ne $file.Name) {
            Log -Category "Clean" -Message ("Removing {0}" -f $file.Name)
            Remove-Item -Path $file.FullName -Force
        }
    }

    $files_dir = ("{0}\files" -f $state.output_path)
    if (Test-Path $files_dir)  {
        Remove-Item -Path ("{0}\*" -f $files_dir) -Force -Recurse
    }
}


function Sync {

	$source_files = @();
	foreach($cpath in $site.content_path) {
		#Write-Host ("******* {0}" -f $cpath)
		if (-not $cpath.Contains(":")) {
			$cpath = ("{0}\{1}" -f $script:state.working_path, $cpath)
		}
    	$source_files = $source_files + (Get-ChildItem -Path ("{0}\*" -f $cpath) -Include *.md -Recurse | Sort-Object -Property Name)
	}
	$source_files = ($source_files | Sort-Object -Property "Name")
	
    $oposts = @()

    foreach ($file in $source_files) {
		#Write-Host $file
        $opost = (Parse -File $file)
        $oposts += $opost

        # if ($state.sync) {

        #     $opost = (Parse -File $file)

        # } else {
        #     $opost = ($state.posts | Where-Object { $_.source -eq $file.fullpath -and $file.LastWriteTime -gt $_.updated } | Select-Object -First 1)

        #     if (-not $opost) {
        #         $opost = (Parse -File $file)
        #         $oposts += $opost
        #     }
        # }
    }

    $script:state.posts = ($oposts | Where-Object { $_.type -eq "post" } | Sort-Object { $_.date } -Descending)
    $script:state.pages = ($oposts | Where-Object { $_.type -eq "page" } | Sort-Object { $_.date } -Descending)

    # Build out the topics data structure
    $ptopics = @()
    $ltopics = @()
    foreach ($post in $state.posts) {
        #Write-Host $post.title
        $ptopic = $null

        if ($post.published -and $post.date -lt $now) {

            foreach ($topic in $post.topics) {
                $rtopic = $topic
                $topic = $topic.ToLower().Trim()
                if ($ltopics -contains $topic) {
                    $ptopic = ($ptopics | Where-Object { $_.name -eq $topic } | Select-Object -First 1)
                    if ($post.updated -gt $ptopic.updated) {
                        $ptopic.updated = $post.updated    
                    }
                } else {
                    $ptopic = @{ "name" = $topic; "title" = $rtopic; "slug" = ($topic -replace "\W", "-"); "posts" = @(); } 
                    $ptopic.filename = ("topic-{0}.html" -f $ptopic.slug)
                    $ptopic.filepath = ("{0}\{1}" -f $state.output_path, $ptopic.filename)
                    $ptopic.updated = $post.updated
                    $ptopics += $ptopic
                }
                $ltopics += $topic
                $ptopic.posts += $post
            }
        }
    }
    $script:state.topics = ($ptopics | Sort-Object { $_.name })
}


function Parse {
    param($File)
        
        [System.Reflection.Assembly]::LoadWithPartialName("System.web") | Out-Null

        $post = @{
            "title" = "";
            "topics" = @( "Uncategorized" )
            "published" = $True;
            "body_markdown" = "";
            "body" = "";
            "type" = "post";
            "source" = $File.FullName
        }

        #$reader = [System.IO.File]::ReadAllLines($File)
        $reader = (Get-Content -Path $File)

        try {
			$post["comments"] = $False
			$post["published"] = $True
            $header_active = $False

            foreach ($line in $reader) {
                #$line = $reader.ReadLine()
                if ($line -eq $null) { break }
                
                if ($line.StartsWith("-") -or $line.StartsWith("***")) {
                    if ($header_active) {
                        $header_active = $False    
                    } else {
                        $header_active = $True
                    }                    
                } else {
                    if ($header_active) {
                        if ($line.Contains(":")) {
                            $parts = $line.Split(":")
                            $key = $parts[0].Trim()
                            $value = [string]::Join(":", ($parts | Select-Object -Last ($parts.Count - 1)))
                            $value = $value.Trim()
							
							#Write-Host ("*************************** {0} = {1}" -f $key, $value)

                            if ($key -eq "date") {
                                $value = (Get-Date $value)
                            } elseif ($key -eq "comments") {
								
                                $value = [System.Convert]::ToBoolean($value)
                            } elseif ($key -eq "published") {
                                $value = [System.Convert]::ToBoolean($value)
                            } elseif ($key -eq "topics") {
                                $value = $value.Split(",")
                            } else {
                                $value = $value.Trim()
                            }
							
							# Write-Host ("****** {0} = {1}" -f $key, $value)

                            $post[$key] = $value
                            
                            #Log -Category "Parse-Post" -Message ("{0,15}: {1}" -f $key, $post[$key])
                        }
                    } else {
                        $post.body_markdown += $line + "`r`n"
                    }
                }

            }
        }
        finally {
            #$reader.Close()
        }


        # -AutoNewlines -EmptyElementSuffix ' />'
        $post.body = ($post.body_markdown | ConvertFrom-Markdown -AutoHyperlink -EncodeProblemUrlCharacters -LinkEmails -StrictBoldItalic -Verbose -AutoNewlines -EmptyElementSuffix " />")
        $post.body_encoded = [system.web.httputility]::htmlencode($post.body)
        $post.title_encoded = [system.web.httputility]::htmlencode($post.title)

        if ($post.slug -eq $null) {
            $post.slug = $post.title -replace "\W", "-"
            $post.slug = $post.slug -replace "(-+)$"
            $post.slug = $post.slug -replace "^(-+)"
            $post.slug = $post.slug -replace "--", "-"
        }
        $post.slug = $post.slug.ToLower()

        if ($post.ContainsKey("date")) {
            if ($post.type -eq "page") {
                $post.filename = "{0}.html" -f $post.slug
				$post.json_filename = "{0}.json" -f $post.slug
            } else {
                $post.filename = "{0:yyyy-MM-dd}-{1}.html" -f $post.date, $post.slug
                $post.json_filename = "{0:yyyy-MM-dd}-{1}.json" -f $post.date, $post.slug
            }
            $post.filepath = "{0}\{1}" -f $state.output_path, $post.filename
            $post.json_filepath = "{0}\{1}" -f $state.output_path, $post.json_filename
            $post.date_formatted = ("{0:d-MMM-yyyy}" -f $post.date)
            $post.date_iso = ("{0:yyyy-MM-ddTHH:mm:ssZ}" -f $post.date)
            $post.date_utc_iso = ("{0:yyyy-MM-ddTHH:mm:ssZ}" -f $post.date.ToUniversalTime())
        } else {
            $post.filename = "{0}.html" -f $post.slug
            $post.filepath = "{0}\{2}" -f $state.output_path, $post.date, $post.filename
        }

        $post.url = $post.filename
        $post.full_url = "{0}/{1}" -f $site.url, $post.url
        if (-not $post.ContainsKey("link")) {
            $post.link = $post.url
        }

        $post.updated = (Get-Item -Path $File.FullName).LastWriteTime
        $post.updated_iso = ("{0:yyyy-MM-ddTHH:mm:ss}" -f $post.updated)
        $post.updated_utc_iso = ("{0:yyyy-MM-ddTHH:mm:ssZ}" -f $post.updated.ToUniversalTime())

        #Write-Host $post.date_iso
        #Write-Host $header
        #Write-Host $body_markdown
        #Write-Host $post.title
        #Write-Host $post.body_markdown
        #Write-Host ($post | Out-String)

        #Write-Host $post.body

		$publish_msg = ""
		if ($post.date -gt $now) {
			$publish_msg = (", Date: {0:ddd d-MMM-yyyy h:mm tt}" -f $post.date)
		}

        if (-not $post.published) {
            Log -Category "Parse" -Message ("{0} (Draft{1})" -f $File.Name, $publish_msg) -Color Yellow
        } elseif ($post.date -gt $now) {
            Log -Category "Parse" -Message ("{0} (Future Publish{1})" -f $File.Name, $publish_msg) -Color Yellow
        } else {
            Log -Category "Parse" -Message $File.Name
        }

        return $post
}


function Publish {
    Publish-Files
    Publish-Posts
    Publish-Pages
    Publish-BlogIndex
    Publish-Archive
    Publish-TopicIndex
    Publish-TopicPages
    Publish-Feed
    Publish-Feed -SiteMap
}


function Finalize {
    # Log -Category "Finalize" -Message ("Saving state...")    
    # $state | ConvertTo-JSON -Depth 10 | Set-Content -Path $state.state_path
    #Log -Category "Finalize" -Message ("Saved -- {0}" -f $state.state_path)

    $script:end_time = (Get-Date)

    Log -Category "Finalize" -Message ("Processed {0:N0} Posts, {1:N0} Pages in {2}" -f $state.posts.Length, $state.pages.Length, ($end_time - $start_time))
    Log -Category "Finalize" -Message ("Done.")
}


function Publish-Posts {

    $posts = ($state.posts | Where-Object { $state.preview -or ($_.published -and $_.date -lt $now) })

    foreach ($post in $posts) {
        
        if (-not $state.full) {
            if (Test-Path $post.filepath) {
                $file = (Get-Item -Path $post.filepath)
                if ($file.LastWriteTime -gt $post.updated) {
                    continue
                }
            }
        }

		$model = @{
			"Mode" = "Single";
			"Site" = $site;
			"State" = $state;
			"Posts" = @(,$post);
			"Post" = $post;
		}

		Render -Path $post.filepath -Model $model
		
		#$model.Mode = "SingleJson"
		#Render -Path $post.json_filepath -Model $model

    }
}


function Publish-Pages {
    param($Pages = $null)

    if ($Pages -eq $null) {
        $Pages = $state.pages
    }

    foreach ($page in $Pages) {

        if (-not $state.full) {
            if (Test-Path $page.filepath) {
                $file = (Get-Item -Path $page.filepath)
                if ($file.LastWriteTime -gt $page.updated) {
                    continue
                }
            }
        }

        if (-not $page.published) {
            Log -Category "Publish" -Message ("Skipping {0} (draft) " -f $page.slug) -Color Yellow
            continue
        }

        if ($page.slug -eq "index") {
            $blog_index_slug = "blog"
        }

		$model = @{
			"Mode" = "Single";
			"Site" = $site;
			"State" = $state;
			"Posts" = @(,$page);
			"Post" = $page;
			"Page" = $page;
		}

		Render -Path $page.filepath -Model $model

#        $content = (Render-Post -Post $page)
#        Render-MainTemplate -Content $content -Path $page.filepath -BrowserTitle ('{0} :: {1}' -f $page.title, $site.title)
    }

}


function Publish-BlogIndex {
    $filename = "index.html"
    $ipage = ($state.pages | Where-Object { $_.slug -eq 'index' } | Select-Object -First 1)
    if ($ipage) {
        $filename = "blog.html"
    }

    $filepath = ("{0}\{1}" -f $state.output_path, $filename)

    $posts = ($state.posts | Where-Object { $state.preview -or ($_.published -and $_.date -lt $now) } | Select-Object -First $site.index_post_count)
    $last_post = ($posts | Sort-Object { $_.updated } -Descending | Select-Object -First 1)

	# Should I publish the blog index?
    if (-not $state.full) {
        if (Test-Path $filepath) {
            $file = (Get-Item -Path $filepath)
            if ($file.LastWriteTime -gt $last_post.updated) {
                return
            }
        }
    }

	if ($posts -isnot [system.array]) {
		$posts = @(,$posts)
	}

	$model = @{
		"Mode" = "BlogIndex";
		"Site" = $site;
		"State" = $state;
		"Posts" = $posts;
	}

    Render -Path $filepath -Model $model
}


function Publish-Archive {

    $filename = "archive.html"
    $filepath = ("{0}\{1}" -f $state.output_path, $filename)

    $posts = ($state.posts | Where-Object { $state.preview -or ($_.published -and $_.date -lt $now) })
    $last_post = ($posts | Sort-Object { $_.updated } -Descending | Select-Object -First 1)

    if (-not $state.full) {
        if (Test-Path $filepath) {
            $file = (Get-Item -Path $filepath)
            if ($file.LastWriteTime -gt $last_post.updated) {
                return
            }
        }
    }

	if ($posts -isnot [system.array]) {
		$posts = @(,$posts)
	}

	$model = @{
		"Mode" = "Archive";
		"Site" = $site;
		"State" = $state;
		"Posts" = $posts;
	}

	Render -Path $filepath -Model $model

}


function Publish-TopicIndex {
    $filename = "topics.html"
    $filepath = ("{0}\{1}" -f $state.output_path, $filename)

    $topics = $state.topics
    $last_post = ($topics | Foreach-Object { $_.posts } | Sort-Object { $_.updated } -Descending | Select-Object -First 1)

    if (-not $state.full) {
        if (Test-Path $filepath) {
            $file = (Get-Item -Path $filepath)
            if ($file.LastWriteTime -gt $last_post.updated) {
                return
            }
        }
    }

	if ($topics -isnot [system.array]) {
		$topics = @(,$topics)
	}

	$model = @{
		"Mode" = "TopicIndex";
		"Site" = $site;
		"State" = $state;
		"Topics" = $topics;
	}

	Render -Path $filepath -Model $model

}


function Publish-TopicPages {

    foreach ($topic in $state.topics) {
        
        if (-not $state.full) {
            if (Test-Path $topic.filepath) {
                $file = (Get-Item -Path $topic.filepath)
                if ($file.LastWriteTime -gt $topic.updated) {
                    continue
                }
            }
        }

        $posts = ($topic.posts | Where-Object { $state.preview -or ($_.published -and $_.date -lt $now) })

		if ($posts -isnot [system.array]) {
			$posts = @(,$posts)
		}

		$model = @{
			"Mode" = "Topic";
			"Site" = $site;
			"State" = $state;
			"Topic" = $topic;
			"Posts" = $posts;
		}

		Render -Path $topic.filepath -Model $model
	}
}


function Publish-Files {
    Log -Category "Files" -Message "Copying..."

    $files_path = ("{0}/files" -f $state.output_path)
    
    if (Test-Path $files_path -PathType Container) {
        Remove-Item -Path $files_path -Force -Recurse
    }
    
    Copy-Item -Path $state.files_path -Destination $files_path -Recurse -Force

    Copy-Item -Path ("{0}\root\*" -f $state.files_path) -Destination $state.output_path -Force

    Log -Category "Files" -Message "Done."
}


function Publish-Feed {
    param([switch]$SiteMap)

    $filename = "feed.xml"
    $limit = 30

    if ($SiteMap) {
        $filename = "sitemap.xml";
        $limit = 10000
    }

    $filepath = ("{0}\{1}" -f $state.output_path, $filename)

    $posts = ($state.posts | Where-Object { $state.preview -or ($_.published -and $_.date -lt $now) } | Select-Object -First $limit)
	if ($posts -isnot [system.array]) {
		$posts = @(,$posts)
	}

	$pages = $state.pages
	if ($pages -isnot [system.array]) {
		$pages = @(,$pages)
	}

	if ($SiteMap) {
        $posts = $pages + $posts
    }

    $last_post = ($posts | Sort-Object { $_.updated } -Descending | Select-Object -First 1)

    if (-not $state.full) {
        if (Test-Path $filepath) {
            $file = (Get-Item -Path $filepath)
            if ($file.LastWriteTime -gt $last_post.updated) {
                return
            }
        }
    }

	if ($posts -isnot [system.array]) {
		$posts = @(,$posts)
	}

	$model = @{
		"Mode" = "Feed";
		"Site" = $site;
		"State" = $state;
		"Posts" = $posts;
	}

	Render -Path $filepath -Model $model

}


function Get-Template{
    param([string]$Name)

    if (-not $script:state.templates.ContainsKey($Name)) {
        $script:state.templates[$Name] = [string](Get-Content -Path ("{0}\{1}" -f $state.template_path, $Name))
    }

    return $script:state.templates[$Name]
}

function Initialize-Template {
    process {

		$razorAssembly = 
            [AppDomain]::CurrentDomain.GetAssemblies() |
                ? { $_.FullName -match "^System.Web.Razor" }
    
        if ($razorAssembly -eq $null) {
            
			$razorSearchPath = "c:\source\Mole\Mole\System.Web.Razor.dll"
			
#            $razorSearchPath = Join-Path `
#                -Path $PWD `
#                -ChildPath packages\AspNetRazor.Core.*\lib\net40\System.Web.Razor.dll
                
            $razorPath = Get-ChildItem -Path $razorSearchPath |
                Select-Object -First 1 -ExpandProperty FullName
            
            if ($razorPath -ne $null) {
                Add-Type -Path $razorPath
            } else {            
                throw "The System.Web.Razor assembly must be loaded."
            }
        }
    
        #
        # A Razor template.
        #
		$TemplateClassName = "t{0}" -f 
            ([System.IO.Path]::GetRandomFileName() -replace "\.", "")
        $TemplateBaseClassName = "t{0}" -f 
            ([System.IO.Path]::GetRandomFileName() -replace "\.", "")
			
		$language = New-Object `
            -TypeName System.Web.Razor.CSharpRazorCodeLanguage
        $engineHost = New-Object `
            -TypeName System.Web.Razor.RazorEngineHost `
            -ArgumentList $language `
            -Property @{
                DefaultBaseClass = ("Mole.{0}" -f $TemplateBaseClassName)
                DefaultClassName = $TemplateClassName;
                DefaultNamespace = "Mole";
            }
        $engine = New-Object -TypeName System.Web.Razor.RazorTemplateEngine -ArgumentList $engineHost
        $stringReader = New-Object -TypeName System.IO.StringReader -ArgumentList $state.template
        $code = $engine.GenerateCode($stringReader)

        # Template compilation.
        $stringWriter = New-Object -TypeName System.IO.StringWriter
        $compiler = New-Object -TypeName Microsoft.CSharp.CSharpCodeProvider
        $compilerResult = $compiler.GenerateCodeFromCompileUnit(
            $code.GeneratedCode, $stringWriter, $null
        )

        $templateBaseCode = [System.IO.File]::ReadAllText($state.template_base_path)
		$templateBaseCode = $templateBaseCode -replace ("MoleTemplate", $TemplateBaseClassName)
	    $templateGeneratedCode = $templateBaseCode + "`n" + $stringWriter.ToString()
		
		# Write-Host $templateBaseCode
		# Write-Host $templateCode
		
        Add-Type `
            -TypeDefinition $templateGeneratedCode `
            -ReferencedAssemblies System.Core, Microsoft.CSharp, System.Web.Extensions
		
		Set-Content -Path ("{0}\Template.generated.cs" -f $state.working_path) -Value $templateGeneratedCode
            
        # Template execution.
        $script:state.template = New-Object -TypeName ("Mole.{0}" -f $TemplateClassName)
	}
}


function Render {

    param (
        [string] $Path,
        [object] $Model
    )

    process {
		# Write-Host $Model
		
		Log -Category "Render" -Message ([System.IO.Path]::GetFileName($Path))
        $file_content = $state.template.Render($Model)
		Set-Content -Path $Path -Value $file_content
	}
}

function Expand-Path{
    param([string]$Path)

    return (Get-Item -Path $Path).FullName
}


function Log {
    param([string]$Category, [string]$Message, [switch]$IncludeTimeStamp, [string]$Key, [string]$Color = "White")
    
    $mask = "[ {0,10}{1} ] {2}{3}"
    $ts = ""
    if ($IncludeTimeStamp) {
        $ts = (" | {0:yyyy-MM-dd HH:mm:ss}" -f (Get-Date))
    }
    if ($Key) {
        $ks = ("{0,23}: " -f $Key)
    }

    $log_out = $mask -f $Category, $ts, $ks, $Message
    
    if ($state.log) {
        Add-Content -Value $log_out -Path $state.log_filepath -Encoding Ascii
    }

    Write-Host -ForegroundColor $Color -Object $log_out
}



