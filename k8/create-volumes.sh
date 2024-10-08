#!/bin/bash

function multiCluster() {
    path=$1
    workers_from=$2
    workers_to=$3
    index=$4

    for i in `eval echo {$workers_from..$workers_to}`;
    do
        for j in `eval echo {1..$index}`;
        do
            echo "$path/worker-$i-$j.qcow2"
            qemu-img create "$path/worker-$i-$j.qcow2" 1G -f qcow2 -o preallocation=full
        done

        for j in `eval echo {$index..15}`;
        do
            echo "$path/worker-$i-$j.qcow2"
            qemu-img create "$path/worker-$i-$j.qcow2" 40G -f qcow2 -o preallocation=full
        done
    done
}

function singleCluster() {
    path=$1
    workers_from=$2
    workers_to=$3
    index=$4

    for i in `eval echo {$workers_from..$workers_to}`;
    do
        for j in `eval echo {1..$index}`;
        do
            echo "$path/worker-$i-$j.qcow2"
            qemu-img create "$path/worker-$i-$j.qcow2" 2G -f qcow2 -o preallocation=full
        done

        for j in `eval echo {$index..15}`;
        do
            echo "$path/worker-$i-$j.qcow2"
            qemu-img create "$path/worker-$i-$j.qcow2" 100G -f qcow2 -o preallocation=full
        done
    done
}

function create() {
    path=$1
    workers_from=$2
    workers_to=$3
    index=$4

    for i in `eval echo {$workers_from..$workers_to}`;
    do
        for j in `eval echo {1..$index}`;
        do
            echo "$path/worker-$i-$j.qcow2"
            qemu-img create "$path/worker-$i-$j.qcow2" 100G -f qcow2 -o preallocation=full
        done

        for j in `eval echo {$(( $index + 1 ))..6}`;
        do
            echo "$path/worker-$i-$j.qcow2"
            qemu-img create "$path/worker-$i-$j.qcow2" 5G -f qcow2 -o preallocation=full
        done
    done
}

create $1 $2 $3 $4