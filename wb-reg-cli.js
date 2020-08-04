const exec = require("child_process").exec;
(function () {
    console.log(process.argv)
    return;
    // if git rev-parse --git-dir > /dev/null 2>&1; then

    //     function register () {
    //         return;
    //         REPO=$1

    //         WORKBOOK_TASK_ID=$2

    //         WORKBOOK_TASK_DATA=$( curl -s "https://wbapp.magnetix.dk/api/task/${WORKBOOK_TASK_ID}/visualization" \
    //             -H "Accept: application/json, text/plain, */*" \
    //             -H "Content-Type: application/json" \
    //             -H "Cookie: ${COOKIE}" )

    //         WORKBOOK_TASK_JOBNAME=$( echo $WORKBOOK_TASK_DATA | jq -j '.JobName')

    //         if [[ $WORKBOOK_TASK_JOBNAME =~ $REPO ]]; then

    //             TODAY_STATS=$( echo $ALL_TIME_ENTRIES | jq '[.time_entries | .[] | select(.task.name == "'"$REPO"'")]' )
    //             NUM_OF_ENTRIES=$( echo $TODAY_STATS | jq length)
    //             DESCRIPTION=$( echo $TODAY_STATS | tr '\r\n' ' ' | jq -j '.[] | .notes, " ", .hours, "h\n"')
    //             HOURS=0

    //             COUNTER=0
    //             while [  $COUNTER -lt $NUM_OF_ENTRIES ]; do
    //                 CURRENT_HOURS=$( echo $TODAY_STATS | jq  " .[${COUNTER}] | .hours" )
    //                 let HOURS="$(($HOURS+${CURRENT_HOURS}))"


    //                 let COUNTER=COUNTER+1
    //             done

    //             echo "${green}Registering to ${blue}${WORKBOOK_TASK_JOBNAME} "
    //             echo "${green}Hours: ${blue}${HOURS}"
    //             echo "${green}Description: ${blue}${DESCRIPTION}"

    //             REGISTER_TIME_REQUEST=$( curl -s "https://wbapp.magnetix.dk/api/personalexpense/timeentry/week" \
    //                 -H "Accept: application/json, text/plain, */*" \
    //                 -H "Content-Type: application/json" \
    //                 -H "Cookie: ${COOKIE}" \
    //                 -X "POST" \
    //                 -d '{"ResourceId":'$WORKBOOK_USER_ID',"TaskId":'$WORKBOOK_TASK_ID',"Hours":'$HOURS',"Description":"'"$DESCRIPTION"'","InternalDescription":"'"$DESCRIPTION"'","Date":'$DATE'T00:00:00.000Z}' )

    //         else
    //             # echo "${red}No Match. ${blue}Couldn't find a match between task: ${REPO} and your booking(s) for the given date. "
    //             # echo "${blue}Please register manually"
    //         fi
    //     }

    //     REPO=$(basename `git rev-parse --show-toplevel`)
    //     if [[ $1 = "Internal" ]]; then
    //         REPO="Internal"
    //         TIME=$3
    //     else
    //         HOURS=$1
    //         DATE=${2:-$(date +'%Y-%m-%d')}

    //         #ESTABLISH AUTHENTICATION TO WORKBOOK
    //         echo "${blue}Establishing authentication to workbook..."

    //         AUTH_WITHOUT_HEADERS=$(curl -s "https://wbapp.magnetix.dk/api/auth/ldap" \
    //             -H "Content-Type: application/json" \
    //             -X "POST" \
    //             -d '{"UserName":"'"$WORKBOOK_USERNAME"'","Password":"'"$WORKBOOK_PASSWORD"'", "RememberMe": true}')

    //         WORKBOOK_USER_ID=$(echo $AUTH_WITHOUT_HEADERS | tr '\r\n' ' ' |  jq '.Id' )

    //         AUTH_WITH_HEADERS=$(curl -i -s "https://wbapp.magnetix.dk/api/auth/ldap" \
    //             -H "Content-Type: application/json" \
    //             -X "POST" \
    //             -d '{"UserName":"'"$WORKBOOK_USERNAME"'","Password":"'"$WORKBOOK_PASSWORD"'", "RememberMe": true}')


    //         if [[ $AUTH_WITH_HEADERS =~ "ss-pid=(.{20})" ]]; then
    //             SS_PID=${match[1]}
    //         elif [[ $AUTH_WITH_HEADERS =~ ss-pid=(.{20}) ]]; then
    //             SS_PID=${BASH_REMATCH[1]}
    //         else
    //             echo "Couldn't authenticate"
    //             return;
    //         fi

    //         if [[ $AUTH_WITH_HEADERS =~ "ss-id=(.{20})" ]]; then
    //             SS_ID=${match[1]}
    //         elif [[ $AUTH_WITH_HEADERS =~ ss-id=(.{20}) ]]; then
    //             SS_ID=${BASH_REMATCH[1]}
    //         else
    //             echo "Couldn't authenticate"
    //             return;
    //         fi

    //         COOKIE="X-UAId=; ss-opt=perm; ss-pid=${SS_PID}; ss-id=${SS_ID};"

    //         FILTER_RESPONSE=$( curl -s "https://wbapp.magnetix.dk/api/schedule/weekly/visualization/data?ResourceIds=${WORKBOOK_USER_ID}&PeriodType=1&Date=${DATE}&Interval=1" \
    //             -H "Accept: application/json, text/plain, */*" \
    //             -H "Content-Type: application/json" \
    //             -H "Cookie: ${COOKIE}" \
    //             -X "POST" \
    //             -d '{}' )

    //         FILTER_RESPONSE_DETAILS=$( echo $FILTER_RESPONSE | jq '.[] | .Data | ."0" | .Details ')

    //         NUM_OF_BOOKINGS=$( echo $FILTER_RESPONSE_DETAILS | jq length)

    //         BOOKINGS_COUNTER=0

    //         while [  $BOOKINGS_COUNTER -lt $NUM_OF_BOOKINGS ]; do

    //             CURRENT_TASK_ID=$( echo $FILTER_RESPONSE_DETAILS | jq  " .[${BOOKINGS_COUNTER}] | .TaskId" )

    //             let BOOKINGS_COUNTER=BOOKINGS_COUNTER+1
    //             echo $CURRENT_TASK_ID
    //             register $REPO $HARVEST_ALL_TIME_ENTRIES $CURRENT_TASK_ID
    //         done
    //     fi
    // else
    //     printf "${red}You need to be in a git repo "
    // fi
})();
var REPO = basename `git rev-parse --show-toplevel`
console.log('REPO', REPO)
