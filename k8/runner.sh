#!/bin/bash

i=0
pidsToKill=()

while [[ $i -lt $1 ]];do
  java -cp consumer-0.0.1-SNAPSHOT.jar SingleProducer &> /dev/null &
  pidsToKill+=($!)
  ((i++))
done

echo "DIE: kill -9 ${pidsToKill[*]}"