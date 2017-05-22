# SlackShell

## Description
This PowerShell module includes various functions that utilize the Slack API to create a command and control channel. The main function, Start-Shell, will connect to a user-specified Slack channel and authenticate using a supplied API authentication token for a given Slack team and user.  Any command typed into the channel will then be executed, in PowerShell, on the host.

Powershell v2 should use the SlackShell-Poshv2.psm1

## Functions
#### Start-Shell
Starts the monitoring of a Slack Channel for commands to be executed in PowerShell. Will connect to the Slack channel every $sleep seconds and pull all new commands.  Commands will be executed on the host in PowerShell.

#### Send-Message
Sends a message to the specific Slack Channel through the API. Messages are sent with a text header with the body of the message being a Slack attachment.

#### Invoke-Job
Starts a new process and executes a command in PowerShell on the host. Utilizes the Start-Job method in PowerShell to spawn a new process, wait for the job to finish, and return the output.

#### Invoke-Command
Executes a command in PowerShell on the host in the current context of the running process and returns the output.

#### Get-SlackMessage
Returns all messages in a specific Slack channel from the oldest time period to present. Messages returned in JSON format per the API specifications.

#### Test-Connection
Uses a Slack API call to test if the API token supplied is valid.

## Key Parameters
##### Token
The API token that is used for authentication.  This token represents a specific user on a specific Slack team.  More info can be found here: https://api.slack.com/custom-integrations/legacy-tokens

##### Channel
The channel identifier that specifies which Slack channel in the team will be used. All text in this channel will then be processed as commands on the host when Start-Shell is run.  The Channel ID can be found in the URL when accessing the channel page from the Web-based Slack site.

Example: https://slackteam1.slack.com/messages/ABC123456.  The channel ID is "ABC123456".

## Usage
Import-Module ./SlackShell.psm1

Start-Shell -Token "xoxp-175828824580-175707545555-176600001223-826315a84e533c482bb7e20e8312fh45k" -Channel "ABC123456" -Sleep 5

## Reserved Shell Commands (in the Slack channel)
#### exit
Closes the shell and connection.

#### cd \<path>
Changes the directory of the main process. Relative paths can be used (e.g. cd ..)

#### sleep \<int>
Changes the sleep time.

## Acknowledgments
Inspiration for working with the Slack API in PowerShell is credited to Warren Frame. His repo was a great resource to get started: https://github.com/RamblingCookieMonster/PSSlack
