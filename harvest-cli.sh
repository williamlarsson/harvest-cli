alias hv=harvest

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

    elif [ "$1" = "internal" ]; then
        COMMIT_MESSAGE="${@:2}"

        TODAY=$(date +'%Y-%m-%d')
        TODAYS_ENTRIES=$(curl -s "https://api.harvestapp.com/v2/time_entries?from=$TODAY" \
            -H "Authorization: Bearer $ACCESS_TOKEN" \
            -H "Harvest-Account-Id: $ACCOUNT_ID" )

        TIME_ENTRY_ID=$( echo $TODAYS_ENTRIES | jq '.time_entries | .[] | select(.notes == "'"${COMMIT_MESSAGE}"'") | .id' )

        if [ "$TIME_ENTRY_ID" = "" ]; then
            REPO="Internal"

            allTaskAssignments=$(curl -s "https://api.harvestapp.com/v2/task_assignments?is_active=true" \
                -H "Authorization: Bearer $ACCESS_TOKEN" \
                -H "Harvest-Account-Id: $ACCOUNT_ID" )

            REPO_TASK_ID=$( echo $allTaskAssignments | jq '.task_assignments | .[] | select(.task.name == "'"${REPO}"'") | .task.id' )

            printf "${green}Adding new entry to: ${blue}$REPO${green} with message: ${blue}${COMMIT_MESSAGE}\n${reset}";
            UPDATED_TIME_ENTRY=$(curl -s "https://api.harvestapp.com/v2/time_entries" \
                -H "Authorization: Bearer $ACCESS_TOKEN" \
                -H "Harvest-Account-Id: $ACCOUNT_ID" \
                -X POST \
                -H "Content-Type: application/json" \
                -d '{"project_id": "'"$PROJECT"'","task_id":"'"$REPO_TASK_ID"'","spent_date":"'"$TODAY"'", "notes":"'"$COMMIT_MESSAGE"'"}')
        else
            printf "${green}Continue time entry: ${blue}${COMMIT_MESSAGE}  \n${reset}";
            RESTARTED_TIME_ENTRY=$(curl -s "https://api.harvestapp.com/v2/time_entries/${TIME_ENTRY_ID}/restart" \
                -H "Authorization: Bearer $ACCESS_TOKEN" \
                -H "Harvest-Account-Id: $ACCOUNT_ID" \
                -X PATCH)
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
                    # if [[ $currentBranch =~ ' cell=([^;]+)' ]]; then
                    #     cell=$match[1] # -> $cell == 'ABC'

                    if [[ $currentBranch =~ '/(.*)' ]]; then
                        task=${match[1]}
                        COMMIT_MESSAGE="${task}"
                    else
                        COMMIT_MESSAGE="${*}"
                    fi
                fi
            else
                COMMIT_MESSAGE="${@:1}"
            fi

            REPO=$(basename `git rev-parse --show-toplevel`)
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
