#!/bin/bash

# test out parallelising multiple function calls

# echo ${@}
# echo ${#}
# echo ${0}

# if [[ ${1} == "" ]]; then
#   echo yay
# else  
#   echo nay
# fi

# echo $(if [[ ${1} == "" ]]; then shell; else  ${@}; fi)

# c=5


# curl -w "DNS_resolution: %{time_namelookup}| TCP_negotiation_time: %{time_connect}| SSL_negotiation_time: %{time_appconnect}| TTFB: %{time_starttransfer}| Total time: %{time_total} \n" -o /dev/null -vsL https://www.maya-thai-massage.com



function invokeUrl() {
    for i in {1..1000}
    do
        curl https://wojtek-kedzior.com/$(echo $RANDOM)
        echo "done $i"
    done
}

function erawan() {
    for i in {1..1000}
    do
        curl https://erawanprague.cz/$(echo $RANDOM)
    done
}

function natwhy() {
    for i in {1..1000}
    do
        curl https://natwhy.cz/$(echo $RANDOM)
    done
}

idsToKill=()


invokeUrl &
# source test-2.sh; tes 1 &
pidsToKill+=($!)

# source test-2.sh; tes 2 &
erawan &
pidsToKill+=($!)

natwhy &
pidsToKill+=($!)

echo "${pidsToKill[@]}"

# id=$!

wait "${pidsToKill[@]}"

echo "all done"







