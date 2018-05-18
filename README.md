# SlackShell

## Description & Changelog
### v1.0
This PowerShell module includes various functions that utilize the Slack API to create a command and control channel. The main function, Start-Shell, will connect to a user-specified Slack channel and authenticate using a supplied API authentication token for a given Slack team and user.  Any command typed into the channel will then be executed, in PowerShell, on the host. 

The SlackShell project requires PowerShell v3 and above due to the use of Invoke-RestMethod for API calls.  Future development will continue to use current PowerShell cmdlets and functions. However, a port for Powershell v2 was created in SlackShell-Poshv2.psm1.

### v1.1
Additional PS scripts can be imported into the running session by first uploading them to the Slack channel. The import feature will download the files, which are hosted at https://slack-files.com by default, and import them in memory. The files do not touch disk. Conversely, the download feature can be used to save a local copy of any file to disk. 

Local files can be uploaded to the Slack channel through the API using the upload feature.

If needed, a seperate PS process can be spawned to run a command which utilized the built-in Invoke-Command cmdlet.

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

#### Get-FileList
Uses a Slack API call to return a list of files currently hosted in the Slack channel.

#### Import-File
Refreshes the file list then downloads the specified file into memory, creates a new module, and then imports that module. Commands specific to that module can then be entered directly into the Slack channel. The file downloaded does not touch disk.
*This function should be considered in Beta while additional testing is occuring. Some modules behave erratically*

#### Receive-File
Refreses the file list then downloads the specified file to disk. An additional storage path can be included, defaults to the current location.

#### Send-file
Uploads a local file to the Slack channel.

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
Changes the directory in the contect of the main process. Relative paths can be used (e.g. cd ..)

#### sleep \<int>
Changes the sleep time.

#### files
Listed available files in the associated Slack channel.

#### import \<filename>
Imports specified file. File must be shared with the Slack channel that is being used.

#### download \<filename> \<path>
Downloads the specified file to disk and stores it at optional path paramter location. File must be shared with the Slack channel that is being used.

#### upload \<local filename>
Uploads the local file to Slack and shares it with the channel that is being used.

#### runjob \<command>
Runs the specified command in a new PowerShell process.


## Acknowledgments
Inspiration for working with the Slack API in PowerShell is credited to Warren Frame. His repo was a great resource to get started: https://github.com/RamblingCookieMonster/PSSlack

Special thanks to @thesubtlety for porting over to POSHv2 and added enhancements.
