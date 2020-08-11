alias hv=harvest

function convertTime() {
    if [[ $1 =~ "(.)\:(..)" ]]; then
        MINUTES="$(($match[2] * 1 / 6))"
        HOURS=${match[1]}
        FORMATTED_TIME="${HOURS}.${MINUTES}"
        echo $FORMATTED_TIME
        return $FORMATT ED_TIME
    else
        echo $1
    fi
}

function register () {
    REPO=$1
    HARVEST_ALL_TIME_ENTRIES=$2

    WORKBOOK_TASK_ID=$3

    WORKBOOK_TASK_DATA=$( curl -s "https://wbapp.magnetix.dk/api/task/${WORKBOOK_TASK_ID}/visualization" \
        -H "Accept: application/json, text/plain, */*" \
        -H "Content-Type: application/json" \
        -H "Cookie: ${COOKIE}" )

    WORKBOOK_TASK_JOBNAME=$( echo $WORKBOOK_TASK_DATA | jq -j '.JobName')
    TRIMMED_WORKBOOK_TASK_JOBNAME=$( echo "$WORKBOOK_TASK_JOBNAME" | tr '[:upper:]' '[:lower:]' )
    TRIMMED_WORKBOOK_TASK_JOBNAME=${TRIMMED_WORKBOOK_TASK_JOBNAME// /}

    TRIMMED_REPO=$( echo "$REPO" | tr '[:upper:]' '[:lower:]' )
    TRIMMED_REPO=${TRIMMED_REPO// /}

    if [[ $TRIMMED_WORKBOOK_TASK_JOBNAME =~ $TRIMMED_REPO ]]; then

        ALL_TIME_ENTRIES=$(curl -s "https://api.harvestapp.com/v2/time_entries?from=$DATE&to=$DATE" \
            -H "Authorization: Bearer $ACCESS_TOKEN" \
            -H "Harvest-Account-Id: $ACCOUNT_ID" )

        TODAY_STATS=$( echo $ALL_TIME_ENTRIES | jq '[.time_entries | .[] | select(.task.name == "'"$REPO"'")]' )
        NUM_OF_ENTRIES=$( echo $TODAY_STATS | jq length)
        DESCRIPTION=$( echo $TODAY_STATS | tr '\r\n' ' ' | jq -j '.[] | .notes, " ", .hours, "h\n"')
        HOURS=0

        COUNTER=0
        while [  $COUNTER -lt $NUM_OF_ENTRIES ]; do
            CURRENT_HOURS=$( echo $TODAY_STATS | jq  " .[${COUNTER}] | .hours" )
            let HOURS="$(($HOURS+${CURRENT_HOURS}))"

            let COUNTER=COUNTER+1
        done

        echo "${green}Registering to ${blue}${WORKBOOK_TASK_JOBNAME} "
        echo "${green}Hours: ${blue}${HOURS}"
        echo "${green}Description: ${blue}${DESCRIPTION}\n"

        REGISTER_TIME_REQUEST=$( curl -s "https://wbapp.magnetix.dk/api/personalexpense/timeentry/week" \
            -H "Accept: application/json, text/plain, */*" \
            -H "Content-Type: application/json" \
            -H "Cookie: ${COOKIE}" \
            -X "POST" \
            -d '{"ResourceId":'$WORKBOOK_USER_ID',"TaskId":'$WORKBOOK_TASK_ID',"Hours":'$HOURS',"Description":"'"$DESCRIPTION"'","InternalDescription":"'"$DESCRIPTION"'","Date":'$DATE'T00:00:00.000Z}' )

    else
        echo "${red}No Match. ${blue}Couldn't find a match between task: ${REPO} and your booking(s) for the given date. "
        echo "${blue}Please register manually"
    fi
}

function registerInternal () {

    HARVEST_TASK_DATA=$1

    WORKBOOK_JOB_ID=$2

    ALL_STATS_TODAY=$(curl -s "https://api.harvestapp.com/v2/time_entries?from=$DATE&to=$DATE" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Harvest-Account-Id: $ACCOUNT_ID" )

    NOTES=$( echo $HARVEST_TASK_DATA | jq '.notes' )
    DESCRIPTION=$( echo $HARVEST_TASK_DATA | jq '.notes' )
    HOURS=$( echo $HARVEST_TASK_DATA | jq '.hours' )

    echo "${green}\nTask: ${blue}Internal"
    echo "${green}Description: ${blue}${DESCRIPTION}"

    echo "${green}Please choose which task type you want to register to:${reset}"


    WORKBOOK_TASK_DATA=$( curl -s "https://wbapp.magnetix.dk/api/json/reply/TasksTimeRegistrationRequest?ResourceId=${WORKBOOK_USER_ID}&JobId=${WORKBOOK_JOB_ID}" \
        -H "Accept: application/json, text/plain, */*" \
        -H "Content-Type: application/json" \
        -H "Cookie: ${COOKIE}" )

    WORKBOOK_TASK_DATA_LENGTH=$( echo $WORKBOOK_TASK_DATA | jq length)
    WORKBOOK_TASK_DATA_COUNTER=0

    while [  $WORKBOOK_TASK_DATA_COUNTER -lt $WORKBOOK_TASK_DATA_LENGTH ]; do
        CURRENT_WORKBOOK_TASK=$( echo $WORKBOOK_TASK_DATA | jq  " .[${WORKBOOK_TASK_DATA_COUNTER}] | .TaskName" )
        echo "$((WORKBOOK_TASK_DATA_COUNTER + 1)) : $CURRENT_WORKBOOK_TASK"
        let WORKBOOK_TASK_DATA_COUNTER=WORKBOOK_TASK_DATA_COUNTER+1
    done

    echo -n "Enter number and press [ENTER]: "
    read USER_WORKBOOK_TASK

    # DEDUCT 1 TO MATCH ARRAY INDEXING
    USER_WORKBOOK_TASK=$(( USER_WORKBOOK_TASK - 1))


    echo "${green}\nRegistering to ${blue}Internal"
    echo "${green}Hours: ${blue}${HOURS}"
    echo "${green}Description: ${blue}${DESCRIPTION}"

    #COLLECT DATA FROM WB ACCORDING TO USER CHOICE

    WORKBOOK_TASK_ID=$( echo $WORKBOOK_TASK_DATA | jq  " .[${USER_WORKBOOK_TASK}] | .Id" )
    WORKBOOK_TASK_NUMBER=$( echo $WORKBOOK_TASK_DATA | jq  " .[${USER_WORKBOOK_TASK}] | .TaskNumber" )


    WORKBOOK_WEEKLY_DATA=$( curl -s "https://wbapp.magnetix.dk/api/json/reply/TimeEntryDailyRequest?ResourceId=${WORKBOOK_USER_ID}&Date=${DATE}" \
        -H "Accept: application/json, text/plain, */*" \
        -H "Content-Type: application/json" \
        -H "Cookie: ${COOKIE}" )

    WORKBOOK_ID=$( echo $WORKBOOK_WEEKLY_DATA  | tr '\r\n' ' ' | jq -j '[ .[] | select(.TaskId == '${WORKBOOK_TASK_ID}') ] | [first] | .[] | .Id' )


    REGISTER_TIME_REQUEST=$( curl -s "https://wbapp.magnetix.dk/api/json/reply/TimeEntryUpdateRequest" \
        -H "Accept: application/json, text/plain, */*" \
        -H "Content-Type: application/json" \
        -H "Cookie: ${COOKIE}" \
        -X "POST" \
        -d '{"ResourceId":'$WORKBOOK_USER_ID',"Id": '${WORKBOOK_ID}', "ActivityId": 999, "Billable": false, "TaskId":'${WORKBOOK_TASK_ID}',"Hours":'${HOURS}',"Description":'$DESCRIPTION',"InternalDescription":'$DESCRIPTION',"Date":'$DATE'T00:00:00.000Z}' )
    # REGISTER_TIME_REQUEST=$( curl -s "https://wbapp.magnetix.dk/api/json/reply/TimeEntryUpdateRequest" \
    #     -H "Accept: application/json, text/plain, */*" \
    #     -H "Content-Type: application/json" \
    #     -H "Cookie: ${COOKIE}" \
    #     -X "POST" \
    #     -d '{"ResourceId":'$WORKBOOK_USER_ID',"Id": '${WORKBOOK_ID}', "ActivityId": 999, "Billable": 'false',"TaskId":'${WORKBOOK_TASK_ID}',"Hours":3,"Description":"'"$DESCRIPTION"'","InternalDescription":"'"$DESCRIPTION"'","Date":'$DATE'T00:00:00.000Z}' )

    # Request URL: https://workbook.magnetix.dk/api/json/reply/TimeEntryUpdateRequest

    # Id: 6234477, ActivityId: 999, Billable: false, Hours: 1, TaskId: 54721, Description: "asdf↵"}
    # ActivityId: 999
    # Billable: false
    # Description: "asdf↵"
    # Hours: 1
    # Id: 6234477
    # TaskId: 54721
}

function harvest(){
    # install jq before usage > brew install jq
    magenta=`tput setaf 5`
    blue=`tput setaf 4`
    red=`tput setaf 1`
    green=`tput setaf 2`
    reset="$(tput sgr0)"

    if [ "$1" = "deleteTask" ]; then
        if [ $2 ]; then
            REPO=$2
        elif git rev-parse --git-dir > /dev/null 2>&1; then
            REPO=$(basename `git rev-parse --show-toplevel`)
        else
            echo "${red}You need to be in a git repo, or specify taskName:\n";
            echo "${green}harvest deleteTask <name>\n";
            return;
        fi
        ALL_TASKS=$(curl -s "https://api.harvestapp.com/v2/tasks" \
            -H "Authorization: Bearer $ACCESS_TOKEN" \
            -H "Harvest-Account-Id: $ACCOUNT_ID" )

        FETCHED_TASK_ID=$( echo $ALL_TASKS | jq '.tasks | .[] | select(.name == "'"${REPO}"'") | .id' )

        echo "${green}\nDeleting task: ${blue}$REPO\n${reset}";

        curl "https://api.harvestapp.com/v2/tasks/${FETCHED_TASK_ID}" \
            -H "Authorization: Bearer $ACCESS_TOKEN" \
            -H "Harvest-Account-Id: $ACCOUNT_ID" \
            -H "User-Agent: MyApp (yourname@example.com)" \
            -X DELETE


    elif [ "$1" = "newTask" ]; then
        if [ $2 ]; then
            REPO=$2
        elif git rev-parse --git-dir > /dev/null 2>&1; then
            REPO=$(basename `git rev-parse --show-toplevel`)
        else
            echo "${red}You need to be in a git repo, or specify taskName:\n";
            echo "${green}harvest newTask <name>\n";
            return;
        fi

        NEW_TASK=$(curl -s "https://api.harvestapp.com/v2/tasks" \
            -H "Authorization: Bearer $ACCESS_TOKEN" \
            -H "Harvest-Account-Id: $ACCOUNT_ID" \
            -X POST \
            -H "Content-Type: application/json" \
            -d '{"name": "'"$REPO"'"}')

        TASK_ID=$( echo $NEW_TASK | jq '.id' )
        echo "${green}Adding new task with name: ${blue}${REPO}${green} and id: ${blue}${TASK_ID}\n${reset}"

        curl "https://api.harvestapp.com/v2/projects/${PROJECT}/task_assignments" \
            -H "Authorization: Bearer $ACCESS_TOKEN" \
            -H "Harvest-Account-Id: $ACCOUNT_ID" \
            -H "User-Agent: MyApp (yourname@example.com)" \
            -X POST \
            -H "Content-Type: application/json" \
            -d '{"task_id":'$TASK_ID',"is_active":true}'


    elif [ "$1" = "note" ]; then

        CURRENT_TIME_ENTRY=$(curl -s "https://api.harvestapp.com/v2/time_entries?user_id=${USER_ID}&is_running=true" \
            -H "Authorization: Bearer ${ACCESS_TOKEN}" \
            -H "Harvest-Account-Id: ${ACCOUNT_ID}" )

        CURRENT_TIME_ENTRY_ID=$(jq -n "$CURRENT_TIME_ENTRY" | jq .time_entries[0].id)
        CURRENT_TIME_ENTRY_MESSAGE=$(jq -n "$CURRENT_TIME_ENTRY" | jq .time_entries[0].notes)
        CURRENT_TIME_ENTRY_MESSAGE_FORMATTED=$(sed -e 's/^"//' -e 's/"$//' <<<"$CURRENT_TIME_ENTRY_MESSAGE")

        if [ "$CURRENT_TIME_ENTRY_MESSAGE" = "null" ]; then
            NEW_MESSAGE="${@:2}"
        else
            NEW_MESSAGE="$CURRENT_TIME_ENTRY_MESSAGE_FORMATTED\n${@:2}"
        fi

        printf "${green}Adding message: ${blue}${NEW_MESSAGE} ${green}to current running task \n${reset}";

        FORMATTED_MESSAGE="\"notes\":\"$NEW_MESSAGE\""
        UPDATED_TIME_ENTRY=$(curl -s "https://api.harvestapp.com/v2/time_entries/${CURRENT_TIME_ENTRY_ID}" \
            -H "Authorization: Bearer $ACCESS_TOKEN" \
            -H "Harvest-Account-Id: $ACCOUNT_ID" \
            -X PATCH \
            -H "Content-Type: application/json" \
            -d "{${FORMATTED_MESSAGE}}")

    elif [ "$1" = "getTasks" ]; then
        allTasks=$(curl -s "https://api.harvestapp.com/v2/task_assignments?is_active=true" \
            -H "Authorization: Bearer $ACCESS_TOKEN" \
            -H "Harvest-Account-Id: $ACCOUNT_ID" )
        echo $allTasks | jq

    elif [ "$1" = "getCurrentTaskID" ]; then
        REPO=$(basename `git rev-parse --show-toplevel`)
        allTaskAssignments=$(curl -s "https://api.harvestapp.com/v2/task_assignments?is_active=true" \
            -H "Authorization: Bearer $ACCESS_TOKEN" \
            -H "Harvest-Account-Id: $ACCOUNT_ID" )

        REPO_TASK=$( echo $allTaskAssignments | jq '.task_assignments | .[] | select(.task.name == "'"${REPO}"'") | .task.id' )
        echo $REPO_TASK

    elif [ "$1" = "getToday" ]; then
        DATE=${2:-$(date +'%Y-%m-%d')}
        ALL_TIME_ENTRIES=$(curl -s "https://api.harvestapp.com/v2/time_entries?from=$DATE&to=$DATE" \
            -H "Authorization: Bearer $ACCESS_TOKEN" \
            -H "Harvest-Account-Id: $ACCOUNT_ID" )
        TODAY_STATS=$(echo $ALL_TIME_ENTRIES | tr '\r\n' ' ' | jq -j '.time_entries | .[] | .task.name, "\n", .notes, " ", .hours, "\n\n"')
        echo "$TODAY_STATS";

    elif [ "$1" = "internal" ] || [ "$1" = "int" ]; then
        REPO="Internal"
        COMMIT_MESSAGE="${@:2}"

        TODAY=$(date +'%Y-%m-%d')
        TODAYS_ENTRIES=$(curl -s "https://api.harvestapp.com/v2/time_entries?from=$TODAY" \
            -H "Authorization: Bearer $ACCESS_TOKEN" \
            -H "Harvest-Account-Id: $ACCOUNT_ID" )

        MATCHED_TIME_ENTRY_ID=$( echo $TODAYS_ENTRIES | jq '.time_entries | .[] | select(.notes == "'"${COMMIT_MESSAGE}"'") | select(.task.name == "'"$REPO"'") | .id' )

        if [ $MATCHED_TIME_ENTRY_ID ]; then
                printf "${green}Setting time entry with task: ${blue}$REPO${green} and message: ${blue}${COMMIT_MESSAGE}\n${reset}";
                RESTARTED_TIME_ENTRY=$(curl -s "https://api.harvestapp.com/v2/time_entries/${MATCHED_TIME_ENTRY_ID}/restart" \
                    -H "Authorization: Bearer $ACCESS_TOKEN" \
                    -H "Harvest-Account-Id: $ACCOUNT_ID" \
                    -X PATCH)
        else
            ALL_TASK_ASSIGNMENTS=$(curl -s "https://api.harvestapp.com/v2/task_assignments?is_active=true" \
                -H "Authorization: Bearer $ACCESS_TOKEN" \
                -H "Harvest-Account-Id: $ACCOUNT_ID" )

            REPO_TASK_ID=$( echo $ALL_TASK_ASSIGNMENTS | jq '.task_assignments | .[] | select(.task.name == "'"${REPO}"'") | .task.id' )

            printf "${green}Adding new entry to: ${blue}$REPO${green} with message: ${blue}${COMMIT_MESSAGE}\n${reset}";
            UPDATED_TIME_ENTRY=$(curl -s "https://api.harvestapp.com/v2/time_entries" \
                -H "Authorization: Bearer $ACCESS_TOKEN" \
                -H "Harvest-Account-Id: $ACCOUNT_ID" \
                -X POST \
                -H "Content-Type: application/json" \
                -d '{"project_id": "'"$PROJECT"'","task_id":"'"$REPO_TASK_ID"'","spent_date":"'"$TODAY"'", "notes":"'"$COMMIT_MESSAGE"'"}')
        fi

    elif [ "$1" = "stop" ]; then
        printf "${green}Stopping the current task\n";
        CURRENT_ENTRY=$(curl -s "https://api.harvestapp.com/v2/time_entries?is_running=true" \
            -H "Authorization: Bearer $ACCESS_TOKEN" \
            -H "Harvest-Account-Id: $ACCOUNT_ID" )

        CURRENT_ENTRY_ID=$(echo $CURRENT_ENTRY | jq '.time_entries | .[] | .id')

        STOPPED_TIME_ENTRY=$(curl -s "https://api.harvestapp.com/v2/time_entries/${CURRENT_ENTRY_ID}/stop" \
            -H "Authorization: Bearer $ACCESS_TOKEN" \
            -H "Harvest-Account-Id: $ACCOUNT_ID" \
            -X PATCH)

    elif [ "$1" = "time" ]; then
        TIME=$(convertTime $2)

        if [ "$TIME" = "" ]; then
            echo "${red}You must pass amount of hours in format: ${blue}2:30"
        fi
        if git rev-parse --git-dir > /dev/null 2>&1; then
            REPO=$(basename `git rev-parse --show-toplevel`)
            currentBranch=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD)
            if [ "$currentBranch" = "" ]; then
                printf "${red}Couldn't get branchname.\n";
                return;
            else
                if [[ $currentBranch =~ '/(.*)' ]]; then
                    task=${match[1]}
                    COMMIT_MESSAGE="${task}"

                elif [[ $currentBranch =~ /(.*) ]]; then
                    task=${BASH_REMATCH[1]}
                    COMMIT_MESSAGE="${task}"
                else
                    COMMIT_MESSAGE="${*}"
                fi
            fi

            TODAY=$(date +'%Y-%m-%d')
            TODAYS_ENTRIES=$(curl -s "https://api.harvestapp.com/v2/time_entries?from=$TODAY" \
                -H "Authorization: Bearer $ACCESS_TOKEN" \
                -H "Harvest-Account-Id: $ACCOUNT_ID" )

            MATCHED_TIME_ENTRY_ID=$( echo $TODAYS_ENTRIES | jq '.time_entries | .[] | select(.notes == "'"${COMMIT_MESSAGE}"'") | select(.task.name == "'"$REPO"'") | .id' )

            if [ $MATCHED_TIME_ENTRY_ID ]; then
                printf "${green}Updating time entry with task: ${blue}$REPO${green} to time: ${blue}$2\n${reset}";

                UPDATED_TIME_ENTRY=$(curl -s "https://api.harvestapp.com/v2/time_entries/${MATCHED_TIME_ENTRY_ID}" \
                    -H "Authorization: Bearer $ACCESS_TOKEN" \
                    -H "Harvest-Account-Id: $ACCOUNT_ID" \
                    -X PATCH \
                    -H "Content-Type: application/json" \
                    -d '{"hours": '$TIME'}')
            else

               CURRENT_TIME_ENTRY=$(curl -s "https://api.harvestapp.com/v2/time_entries?user_id=${USER_ID}&is_running=true" \
                -H "Authorization: Bearer ${ACCESS_TOKEN}" \
                -H "Harvest-Account-Id: ${ACCOUNT_ID}" )

                CURRENT_TIME_ENTRY_ID=$(echo $CURRENT_TIME_ENTRY | jq '.time_entries | .[] | .id')

                UPDATED_TIME_ENTRY=$(curl -s "https://api.harvestapp.com/v2/time_entries/${CURRENT_TIME_ENTRY_ID}" \
                    -H "Authorization: Bearer $ACCESS_TOKEN" \
                    -H "Harvest-Account-Id: $ACCOUNT_ID" \
                    -X PATCH \
                    -H "Content-Type: application/json" \
                    -d '{"hours": '$TIME'}')

            fi
        else
            CURRENT_TIME_ENTRY=$(curl -s "https://api.harvestapp.com/v2/time_entries?user_id=${USER_ID}&is_running=true" \
                -H "Authorization: Bearer ${ACCESS_TOKEN}" \
                -H "Harvest-Account-Id: ${ACCOUNT_ID}" )

            CURRENT_TIME_ENTRY_ID=$(echo $CURRENT_TIME_ENTRY | jq '.time_entries | .[] | .id')

            UPDATED_TIME_ENTRY=$(curl -s "https://api.harvestapp.com/v2/time_entries/${CURRENT_TIME_ENTRY_ID}" \
                -H "Authorization: Bearer $ACCESS_TOKEN" \
                -H "Harvest-Account-Id: $ACCOUNT_ID" \
                -X PATCH \
                -H "Content-Type: application/json" \
                -d '{"hours": '$TIME'}')
        fi

    elif [ "$1" = "round" ]; then
        if git rev-parse --git-dir > /dev/null 2>&1; then
            REPO=$(basename `git rev-parse --show-toplevel`)
            currentBranch=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD)
            if [ "$currentBranch" = "" ]; then
                printf "${red}Couldn't get branchname.\n";
                return;
            else
                if [[ $currentBranch =~ '/(.*)' ]]; then
                    task=${match[1]}
                    COMMIT_MESSAGE="${task}"

                elif [[ $currentBranch =~ /(.*) ]]; then
                    task=${BASH_REMATCH[1]}
                    COMMIT_MESSAGE="${task}"
                else
                    COMMIT_MESSAGE="${*}"
                fi
            fi

            TODAY=$(date +'%Y-%m-%d')
            TODAYS_ENTRIES=$(curl -s "https://api.harvestapp.com/v2/time_entries?from=$TODAY" \
                -H "Authorization: Bearer $ACCESS_TOKEN" \
                -H "Harvest-Account-Id: $ACCOUNT_ID" )

            MATCHED_TIME_ENTRY=$( echo $TODAYS_ENTRIES | jq '.time_entries | .[] | select(.notes == "'"${COMMIT_MESSAGE}"'") | select(.task.name == "'"$REPO"'")' )
            MATCHED_TIME_ENTRY_TIME=$(echo $MATCHED_TIME_ENTRY | jq '.hours * '${DECIMAL_DELIMITER}' | round / '${DECIMAL_DELIMITER}' ' )
            MATCHED_TIME_ENTRY_ID=$(echo $MATCHED_TIME_ENTRY | jq '.id' )

            if [ $MATCHED_TIME_ENTRY_ID ]; then
                printf "${green}Round time entry with task: ${blue}$REPO${green} and message: ${blue}${COMMIT_MESSAGE}\n${reset}";
                printf "${green}From: ${blue}$(echo $MATCHED_TIME_ENTRY | jq '.hours' )${green} to: ${blue}${MATCHED_TIME_ENTRY_TIME}\n${reset}";

                UPDATED_TIME_ENTRY=$(curl -s "https://api.harvestapp.com/v2/time_entries/${MATCHED_TIME_ENTRY_ID}" \
                    -H "Authorization: Bearer $ACCESS_TOKEN" \
                    -H "Harvest-Account-Id: $ACCOUNT_ID" \
                    -X PATCH \
                    -H "Content-Type: application/json" \
                    -d '{"hours": '$MATCHED_TIME_ENTRY_TIME'}')
            else

               CURRENT_TIME_ENTRY=$(curl -s "https://api.harvestapp.com/v2/time_entries?user_id=${USER_ID}&is_running=true" \
                -H "Authorization: Bearer ${ACCESS_TOKEN}" \
                -H "Harvest-Account-Id: ${ACCOUNT_ID}" )

                CURRENT_TIME_ENTRY_ID=$(echo $CURRENT_TIME_ENTRY | jq '.time_entries | .[] | .id')

                UPDATED_TIME_ENTRY=$(curl -s "https://api.harvestapp.com/v2/time_entries/${CURRENT_TIME_ENTRY_ID}" \
                    -H "Authorization: Bearer $ACCESS_TOKEN" \
                    -H "Harvest-Account-Id: $ACCOUNT_ID" \
                    -X PATCH \
                    -H "Content-Type: application/json" \
                    -d '{"hours": '$TIME'}')

            fi
        else
            CURRENT_TIME_ENTRY=$(curl -s "https://api.harvestapp.com/v2/time_entries?user_id=${USER_ID}&is_running=true" \
                -H "Authorization: Bearer ${ACCESS_TOKEN}" \
                -H "Harvest-Account-Id: ${ACCOUNT_ID}" )

            CURRENT_TIME_ENTRY_ID=$(echo $CURRENT_TIME_ENTRY | jq '.time_entries | .[] | .id')

            UPDATED_TIME_ENTRY=$(curl -s "https://api.harvestapp.com/v2/time_entries/${CURRENT_TIME_ENTRY_ID}" \
                -H "Authorization: Bearer $ACCESS_TOKEN" \
                -H "Harvest-Account-Id: $ACCOUNT_ID" \
                -X PATCH \
                -H "Content-Type: application/json" \
                -d '{"hours": '$TIME'}')
        fi

    elif [ "$1" = "register" ] || [ "$1" = "reg" ]; then

        DATE=${2:-$(date +'%Y-%m-%d')}

        #FETCH HARVEST DATA
        echo "${blue}Fetching data from harvest..."
        HARVEST_ALL_TIME_ENTRIES=$(curl -s "https://api.harvestapp.com/v2/time_entries?from=$DATE&to=$DATE" \
            -H "Authorization: Bearer $ACCESS_TOKEN" \
            -H "Harvest-Account-Id: $ACCOUNT_ID" )

        HARVEST_TASKS=$( echo $HARVEST_ALL_TIME_ENTRIES | jq '[.time_entries | .[]]')
        HARVEST_TASK_NAMES=$( echo $HARVEST_ALL_TIME_ENTRIES | jq '[.time_entries | .[] | .task.name]')
        HARVEST_TASKS_LENGTH=$( echo $HARVEST_TASK_NAMES | jq length )

        #ESTABLISH AUTHENTICATION TO WORKBOOK
        AUTH_WITHOUT_HEADERS=$(curl -s "https://wbapp.magnetix.dk/api/auth/ldap" \
            -H "Content-Type: application/json" \
            -X "POST" \
            -d '{"UserName":"'"$WORKBOOK_USERNAME"'","Password":"'"$WORKBOOK_PASSWORD"'", "RememberMe": true}')

        WORKBOOK_USER_ID=$(echo $AUTH_WITHOUT_HEADERS | tr '\r\n' ' ' |  jq '.Id' )

        AUTH_WITH_HEADERS=$(curl -i -s "https://wbapp.magnetix.dk/api/auth/ldap" \
            -H "Content-Type: application/json" \
            -X "POST" \
            -d '{"UserName":"'"$WORKBOOK_USERNAME"'","Password":"'"$WORKBOOK_PASSWORD"'", "RememberMe": true}')


        if [[ $AUTH_WITH_HEADERS =~ "ss-pid=(.{20})" ]]; then
            SS_PID=${match[1]}
        elif [[ $AUTH_WITH_HEADERS =~ ss-pid=(.{20}) ]]; then
            SS_PID=${BASH_REMATCH[1]}
        else
            echo "Couldn't authenticate"
            return;
        fi

        if [[ $AUTH_WITH_HEADERS =~ "ss-id=(.{20})" ]]; then
            SS_ID=${match[1]}
        elif [[ $AUTH_WITH_HEADERS =~ ss-id=(.{20}) ]]; then
            SS_ID=${BASH_REMATCH[1]}
        else
            echo "Couldn't authenticate"
            return;
        fi

        echo "${blue}Establishing authentication to workbook..."
        COOKIE="X-UAId=; ss-opt=perm; ss-pid=${SS_PID}; ss-id=${SS_ID};"

        FILTER_RESPONSE=$( curl -s "https://wbapp.magnetix.dk/api/schedule/weekly/visualization/data?ResourceIds=${WORKBOOK_USER_ID}&PeriodType=1&Date=${DATE}&Interval=1" \
            -H "Accept: application/json, text/plain, */*" \
            -H "Content-Type: application/json" \
            -H "Cookie: ${COOKIE}" \
            -X "POST" \
            -d '{}' )

        FILTER_RESPONSE_DETAILS=$( echo $FILTER_RESPONSE | jq '.[] | .Data | ."0" | .Details ')

        NUM_OF_BOOKINGS=$( echo $FILTER_RESPONSE_DETAILS | jq length)

        BOOKINGS_COUNTER=0

        HARVEST_TASKS_REGISTERED=""


        while [  $BOOKINGS_COUNTER -lt $NUM_OF_BOOKINGS ]; do

            HARVEST_TASKS_COUNTER=0

            while [  $HARVEST_TASKS_COUNTER -lt $HARVEST_TASKS_LENGTH ]; do

                HARVEST_CURRENT_TASK_NAME=$( echo $HARVEST_TASK_NAMES | jq -j ".[${HARVEST_TASKS_COUNTER}]" )

                if [[ $HARVEST_TASKS_REGISTERED != *${HARVEST_CURRENT_TASK_NAME}* ]] && [[ "$HARVEST_CURRENT_TASK_NAME" != "Internal" ]]; then


                    CURRENT_TASK_ID=$( echo $FILTER_RESPONSE_DETAILS | jq  " .[${BOOKINGS_COUNTER}] | .TaskId" )
                    # echo $HARVEST_CURRENT_TASK_NAME $HARVEST_ALL_TIME_ENTRIES $CURRENT_TASK_ID
                    register $HARVEST_CURRENT_TASK_NAME $HARVEST_ALL_TIME_ENTRIES $CURRENT_TASK_ID
                fi

                HARVEST_TASKS_REGISTERED="${HARVEST_TASKS_REGISTERED}${HARVEST_CURRENT_TASK_NAME}"
                let HARVEST_TASKS_COUNTER=HARVEST_TASKS_COUNTER+1

            done

            HARVEST_TASKS_REGISTERED=""

            let BOOKINGS_COUNTER=BOOKINGS_COUNTER+1

        done

        #REGISTER THROUGH INTERNAL TIME ENTRIES

        HARVEST_TASKS_COUNTER=0

        while [  $HARVEST_TASKS_COUNTER -lt $HARVEST_TASKS_LENGTH ]; do

            HARVEST_CURRENT_TASK_NAME=$( echo $HARVEST_TASK_NAMES | jq -j ".[${HARVEST_TASKS_COUNTER}]" )

            if [[ "$HARVEST_CURRENT_TASK_NAME" = "Internal" ]]; then

                HARVEST_CURRENT_TASK=$( echo $HARVEST_TASKS | jq -j ".[${HARVEST_TASKS_COUNTER}]" )

                registerInternal $HARVEST_CURRENT_TASK 1000
            fi

            let HARVEST_TASKS_COUNTER=HARVEST_TASKS_COUNTER+1

        done

    elif [ "$1" = "help" ]; then
        printf "
        \b\b\b${green}Usage commands:${blue}
        hv                          ${magenta}Toggle timer using git to get task and branchname as message${blue}
        hv <message>                ${magenta}Toggle timer using git to get task and with given message${blue}
        hv internal <message>       ${magenta}Toggle timer to internal task with given message${blue}
        hv stop                     ${magenta}Stops the current timer${blue}
        hv note <message>           ${magenta}Add message to current running task${blue}
        hv getToday                 ${magenta}Get time summary for today${blue}
        hv getToday <yyyy-mm-dd>    ${magenta}Get time summary for given date${blue}
        \b\b\b${green}Utility commands:${blue}
        hv deleteTask               ${magenta}Delete task using current git directory${blue}
        hv deleteTask <name>        ${magenta}Delete task using name${blue}
        hv newTask                  ${magenta}Create task using current git directory${blue}
        hv newTask <name>           ${magenta}Create task using name${blue}
        hv getTasks                 ${magenta}Display all tasks info in JSON${blue}
        \n";

    else
        if git rev-parse --git-dir > /dev/null 2>&1; then
            REPO=$(basename `git rev-parse --show-toplevel`)
            if [ "$1" = "" ]; then
                currentBranch=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD)
                if [ "$currentBranch" = "" ]; then
                    printf "${red}Couldn't get branchname.\n";
                else
                    if [[ $currentBranch =~ '/(.*)' ]]; then
                        task=${match[1]}
                        COMMIT_MESSAGE="${task}"

                    elif [[ $currentBranch =~ /(.*) ]]; then
                        task=${BASH_REMATCH[1]}
                        COMMIT_MESSAGE="${task}"
                    else
                        COMMIT_MESSAGE="${*}"
                    fi
                fi
            else
                COMMIT_MESSAGE="${@:1}"
            fi

            TODAY=$(date +'%Y-%m-%d')
            TODAYS_ENTRIES=$(curl -s "https://api.harvestapp.com/v2/time_entries?from=$TODAY" \
                -H "Authorization: Bearer $ACCESS_TOKEN" \
                -H "Harvest-Account-Id: $ACCOUNT_ID" )

            MATCHED_TIME_ENTRY_ID=$( echo $TODAYS_ENTRIES | jq '.time_entries | .[] | select(.notes == "'"${COMMIT_MESSAGE}"'") | select(.task.name == "'"$REPO"'") | .id' )

            if [ $MATCHED_TIME_ENTRY_ID ]; then
                printf "${green}Continuing time entry with task: ${blue}$REPO${green} and message: ${blue}${COMMIT_MESSAGE}\n${reset}";
                RESTARTED_TIME_ENTRY=$(curl -s "https://api.harvestapp.com/v2/time_entries/${MATCHED_TIME_ENTRY_ID}/restart" \
                    -H "Authorization: Bearer $ACCESS_TOKEN" \
                    -H "Harvest-Account-Id: $ACCOUNT_ID" \
                    -X PATCH)
            else
                ALL_TASK_ASSIGNMENTS=$(curl -s "https://api.harvestapp.com/v2/task_assignments?is_active=true" \
                    -H "Authorization: Bearer $ACCESS_TOKEN" \
                    -H "Harvest-Account-Id: $ACCOUNT_ID" )

                REPO_TASK_ID=$( echo $ALL_TASK_ASSIGNMENTS | jq '.task_assignments | .[] | select(.task.name == "'"${REPO}"'") | .task.id' )

                printf "${green}Adding new entry to: ${blue}$REPO${green} with message: ${blue}${COMMIT_MESSAGE}\n${reset}";
                UPDATED_TIME_ENTRY=$(curl -s "https://api.harvestapp.com/v2/time_entries" \
                    -H "Authorization: Bearer $ACCESS_TOKEN" \
                    -H "Harvest-Account-Id: $ACCOUNT_ID" \
                    -X POST \
                    -H "Content-Type: application/json" \
                    -d '{"project_id": "'"$PROJECT"'","task_id":"'"$REPO_TASK_ID"'","spent_date":"'"$TODAY"'", "notes":"'"$COMMIT_MESSAGE"'"}')

            fi
        else
            printf "${red}You need to be in a git repo, or use the command:\n";
            printf "${green}hv internal <message>\n";
        fi
    fi
}
