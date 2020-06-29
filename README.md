# Harvest Command Line Interface

### Install jq (json parser for bash)
Mac: `brew install jq`

Win: `chocolatey install jq`

### Setup Harvest app
- [Create account](https://www.getharvest.com/signup)
- Download and install the harvest app
- Client: **Isobar** Project: **Coding**
- Visit profile page, get the user id from the url, and update the ```USER_ID```variable in config
- Visit projects page -> your project, get the project ID from the url, and update ```PROJECT`` variable
- Click edit project. Create tasks/clients (eg. Gyldendal, PFA, Studybox, Webapp)
- Visit [developers page] (https://id.getharvest.com/developers), generate an Access token, and update the ```ACCESS_TOKEN``` & ``` ACCOUNT_ID ``` variable
- Open terminal and type ``hv newTask internal`` to create the internal task

### Setup complete

## Usage
*Note that any branches with no slash will generate a time entry with an empty message, so if you're on eg. develop, master, use the ``hv <message>`` command*
###Usage commands:
        hv                          Toggle timer using git to get task and branchname as message
        hv <message>                Toggle timer using git to get task and with given message
        hv internal <message>       Toggle timer to internal task with given message
        hv stop                     Stops the current timer
        hv note <message>           Add message to current running task
        hv getToday                 Get time summary for today
        hv getToday <yyyy-mm-dd>    Get time summary for given

###Utility commands:

        hv deleteTask               Delete task using current git directory
        hv deleteTask <name>        Delete task using name
        hv newTask                  Create task using current git directory
        hv newTask <name>           Create task using name
        hv getTasks                 Display all tasks info in JSON