#!/bin/bash

# test out parallelising multiple function calls

rm out-[1-3] 
rm out-log-[1-3]

function doStuff() {
    index=$1

    for v in {1..10}
    do
        echo $index sleeping on $v
        sleep 1
    done

    echo 1 > out-$index
}

doStuff 1 >> out-log-1 &
doStuff 2 >> out-log-2 & 
doStuff 3 >> out-log-3 &

while [ ! -f out-1 ]
do
    echo "waiting for 1"
    sleep 2
done

checkWorkerUp() {
    index=$1
    while [ ! -f "out-$index" ]
    do
        echo "waiting for $index"
        sleep 2
    done

    echo "out-$index is present"
}

checkWorkerUp 1
checkWorkerUp 2
checkWorkerUp 3

echo $(cat out-1)
echo $(cat out-2)
echo $(cat out-2)

echo $(cat out-log-1)
echo $(cat out-log-2)
echo $(cat out-log-3)

