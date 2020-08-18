function wbRegister () {

    WORKBOOK_TASK_BOOKING=$1

    WORKBOOK_TASK_ID=$( echo $WORKBOOK_TASK_BOOKING | jq -j '.TaskId')


    TOTAL_HOURS_BOOKED=$( echo "$TOTAL_HOURS_BOOKED" + $( echo $WORKBOOK_TASK_BOOKING | jq -j '.Hours') | bc )
    WORKBOOK_REGISTERED_HOURS=$( echo $REGISTERED_TASKS | jq -j '[.[] | select(.TaskId == '$WORKBOOK_TASK_ID') | .Hours ] | add // 0' )

    WORKBOOK_TASK_DATA=$( curl -s "https://wbapp.magnetix.dk/api/task/${WORKBOOK_TASK_ID}/visualization" \
        -H "Accept: application/json, text/plain, */*" \
        -H "Content-Type: application/json" \
        -H "Cookie: ${COOKIE}" )

    echo ""
    echo "${reset}You're booked on: ${green}$( echo $WORKBOOK_TASK_DATA | jq -j '.JobName')"
    echo "${reset}Hours booked: ${green}$( echo $WORKBOOK_TASK_BOOKING | jq -j '.Hours')"
    echo "${reset}Hours registered: ${green}$WORKBOOK_REGISTERED_HOURS"
    echo "${reset}Taskname: ${green}$( echo $WORKBOOK_TASK_DATA | jq -j '.TaskName')"
    echo ""
    echo "${reset}Do want to register a booking?"
    echo "${green}1: ${reset} Yes, I want to book the registered hours: ${green}$( echo $WORKBOOK_TASK_BOOKING | jq -j '.Hours')"
    echo "${green}2: ${reset} Yes, I want to book, but manually enter the amount of hours."
    echo "${green}3: ${reset} No, I don't want to register to this booking"
    echo -n "${reset}Enter number and press [ENTER]: "
    read USER_HOURS

    if [[ "$USER_HOURS" == "1" ]]; then
        USER_HOURS=$( echo $WORKBOOK_TASK_BOOKING | jq -j '.Hours')

    elif [[ "$USER_HOURS" == "2" ]]; then
        echo -n "${reset}Enter amount of desired hours and press [ENTER]: "
        read USER_HOURS

    elif [[ "$USER_HOURS" == "3" ]]; then
        return
    fi


    echo -n "${reset}Enter description for the booking and press [ENTER]: "
    read USER_DESCRIPTION

    echo "${reset}Sending registration to workbook"

    # TOTAL_HOURS_REGISTERED=$( echo "$TOTAL_HOURS_REGISTERED + $USER_HOURS" | bc )
    REGISTER_TIME_REQUEST=$( curl -s "https://wbapp.magnetix.dk/api/personalexpense/timeentry/week" \
        -H "Accept: application/json, text/plain, */*" \
        -H "Content-Type: application/json" \
        -H "Cookie: ${COOKIE}" \
        -X "POST" \
        -d '{"ResourceId":'$WORKBOOK_USER_ID',"TaskId":'$( echo $WORKBOOK_TASK_BOOKING | jq -j '.TaskId')',"Hours":'$USER_HOURS',"Description":"'"$USER_DESCRIPTION"'","InternalDescription":"'"$USER_DESCRIPTION"'","Date":'$DATE'T00:00:00.000Z}' )

}

function wb () {
    magenta=`tput setaf 5`
    blue=`tput setaf 4`
    red=`tput setaf 1`
    green=`tput setaf 2`
    reset="$(tput sgr0)"

    #ESTABLISH AUTHENTICATION TO WORKBOOK
    echo "${reset}Establishing authentication to workbook..."

    AUTH_WITHOUT_HEADERS=$(curl -s "https://wbapp.magnetix.dk/api/auth/ldap" \
        -H "Content-Type: application/json" \
        -X "POST" \
        -d '{"UserName":"'"$WORKBOOK_USERNAME"'","Password":"'"$WORKBOOK_PASSWORD"'", "RememberMe": true}')

    WORKBOOK_USER_ID=$( echo $AUTH_WITHOUT_HEADERS | tr '\r\n' ' ' |  jq '.Id' )

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

    if [[ "$1" = "getToday" ]] || [[ "$1" = "today" ]]; then

        DATE=${2:-$(date +'%Y-%m-%d')}

        FILTER_RESPONSE=$( curl -s "https://wbapp.magnetix.dk/api/schedule/weekly/visualization/data?ResourceIds=${WORKBOOK_USER_ID}&PeriodType=1&Date=${DATE}&Interval=1" \
            -H "Accept: application/json, text/plain, */*" \
            -H "Content-Type: application/json" \
            -H "Cookie: ${COOKIE}" \
            -X "POST" \
            -d '{}' )

        REGISTERED_TASKS=$( curl -s "https://wbapp.magnetix.dk/api/personalexpense/timeentry/visualization/entries?ResourceId=${WORKBOOK_USER_ID}&Date=${DATE}" \
            -H "Accept: application/json, text/plain, */*" \
            -H "Content-Type: application/json" \
            -H "Cookie: ${COOKIE}" )

        # https://workbook.magnetix.dk/api/json/reply/TimeEntryDailyRequest?ResourceId=3644&Date=2020-08-18T00%3A00%3A00.000Z&Week=true


        FILTER_RESPONSE_DETAILS=$( echo $FILTER_RESPONSE | jq '.[] | .Data | ."0" | .Details ')

        NUM_OF_BOOKINGS=$( echo $FILTER_RESPONSE_DETAILS | jq length)

        BOOKINGS_COUNTER=0
        WORKBOOK_REGISTERED_HOURS=0

        echo "${reset}You have ${green}$NUM_OF_BOOKINGS ${reset}booking today."

        while [  $BOOKINGS_COUNTER -lt $NUM_OF_BOOKINGS ]; do

            CURRENT_TASK_BOOKING=$( echo $FILTER_RESPONSE_DETAILS | jq  " .[${BOOKINGS_COUNTER}]" )

            WORKBOOK_TASK_ID=$( echo $CURRENT_TASK_BOOKING | jq -j '.TaskId')
            WORKBOOK_REGISTERED_HOURS=$( echo $REGISTERED_TASKS | jq -j '[.[] | select(.TaskId == '$WORKBOOK_TASK_ID') | .Hours ] | add // 0' )

            WORKBOOK_TASK_DATA=$( curl -s "https://wbapp.magnetix.dk/api/task/${WORKBOOK_TASK_ID}/visualization" \
                -H "Accept: application/json, text/plain, */*" \
                -H "Content-Type: application/json" \
                -H "Cookie: ${COOKIE}" )

            echo ""
            echo "${reset}Client: ${green}$( echo $WORKBOOK_TASK_DATA | jq -j '.JobName')"
            echo "${reset}Hours booked: ${green}$( echo $CURRENT_TASK_BOOKING | jq -j '.Hours')"
            echo "${reset}Hours registered: ${green}$WORKBOOK_REGISTERED_HOURS"
            echo "${reset}Taskname: ${green}$( echo $WORKBOOK_TASK_DATA | jq -j '.TaskName')"
            let BOOKINGS_COUNTER=BOOKINGS_COUNTER+1
            let WORKBOOK_REGISTERED_HOURS
        done


    else
        DATE=${1:-$(date +'%Y-%m-%d')}
        FILTER_RESPONSE=$( curl -s "https://wbapp.magnetix.dk/api/schedule/weekly/visualization/data?ResourceIds=${WORKBOOK_USER_ID}&PeriodType=1&Date=${DATE}&Interval=1" \
            -H "Accept: application/json, text/plain, */*" \
            -H "Content-Type: application/json" \
            -H "Cookie: ${COOKIE}" \
            -X "POST" \
            -d '{}' )

        REGISTERED_TASKS=$( curl -s "https://wbapp.magnetix.dk/api/personalexpense/timeentry/visualization/entries?ResourceId=${WORKBOOK_USER_ID}&Date=${DATE}" \
            -H "Accept: application/json, text/plain, */*" \
            -H "Content-Type: application/json" \
            -H "Cookie: ${COOKIE}" )

        FILTER_RESPONSE_DETAILS=$( echo $FILTER_RESPONSE | jq '.[] | .Data | ."0" | .Details ')

        NUM_OF_BOOKINGS=$( echo $FILTER_RESPONSE_DETAILS | jq length)

        BOOKINGS_COUNTER=0

        TOTAL_HOURS_BOOKED=0
        TOTAL_HOURS_REGISTERED=0

        echo "${reset}Found ${green}$NUM_OF_BOOKINGS ${reset}booking(s) for you."

        while [  $BOOKINGS_COUNTER -lt $NUM_OF_BOOKINGS ]; do

            CURRENT_TASK_BOOKING=$( echo $FILTER_RESPONSE_DETAILS | jq  " .[${BOOKINGS_COUNTER}]" )

            wbRegister "$CURRENT_TASK_BOOKING"

            let BOOKINGS_COUNTER=BOOKINGS_COUNTER+1

        done


        REGISTERED_TASKS=$( curl -s "https://wbapp.magnetix.dk/api/personalexpense/timeentry/visualization/entries?ResourceId=${WORKBOOK_USER_ID}&Date=${DATE}" \
            -H "Accept: application/json, text/plain, */*" \
            -H "Content-Type: application/json" \
            -H "Cookie: ${COOKIE}" )


        BOOKINGS_COUNTER=0

        while [  $BOOKINGS_COUNTER -lt $NUM_OF_BOOKINGS ]; do

            CURRENT_TASK_BOOKING=$( echo $FILTER_RESPONSE_DETAILS | jq  " .[${BOOKINGS_COUNTER}]" )

            WORKBOOK_TASK_ID=$( echo $CURRENT_TASK_BOOKING | jq -j '.TaskId')
            WORKBOOK_REGISTERED_HOURS=$( echo $REGISTERED_TASKS | jq -j '[.[] | select(.TaskId == '$WORKBOOK_TASK_ID') | .Hours ] | add // 0' )

            WORKBOOK_TASK_DATA=$( curl -s "https://wbapp.magnetix.dk/api/task/${WORKBOOK_TASK_ID}/visualization" \
                -H "Accept: application/json, text/plain, */*" \
                -H "Content-Type: application/json" \
                -H "Cookie: ${COOKIE}" )

            echo ""
            echo "${reset}Client: ${green}$( echo $WORKBOOK_TASK_DATA | jq -j '.JobName')"
            echo "${reset}Hours: ${green}$( echo $CURRENT_TASK_BOOKING | jq -j '.Hours')"
            echo "${reset}Hours registered: ${green}$WORKBOOK_REGISTERED_HOURS"
            echo "${reset}Taskname: ${green}$( echo $WORKBOOK_TASK_DATA | jq -j '.TaskName')"
            let TOTAL_HOURS_REGISTERED=TOTAL_HOURS_REGISTERED+WORKBOOK_REGISTERED_HOURS
            let BOOKINGS_COUNTER=BOOKINGS_COUNTER+1

        done
        echo ""
        if [[ $( echo "$TOTAL_HOURS_BOOKED" '<' "$TOTAL_HOURS_REGISTERED" | bc -l) = "1" ]]; then
            echo "${red}Heads up. You have overbooked with ${green}$( echo "$TOTAL_HOURS_REGISTERED" - "$TOTAL_HOURS_BOOKED" | bc )${red} hours. "
            echo "${reset}Visit workbook manually to correct this."

        elif [[ $( echo "$TOTAL_HOURS_BOOKED" '>' "$TOTAL_HOURS_REGISTERED" | bc -l) = "1" ]]; then
            echo "${red}Heads up. You have underbooked with ${green}$( echo "$TOTAL_HOURS_BOOKED" - "$TOTAL_HOURS_REGISTERED" | bc )${red} hours. "
            echo "${reset}Visit workbook manually to correct this."
        else
            echo ""
            echo "${green}Done"
            echo "${reset}Now: ${red} Treci la Traeba!"
        fi

    fi

}

