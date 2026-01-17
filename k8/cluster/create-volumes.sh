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

function staticVolumes() {

    path="/mnt/k8volumes"

    verySmallVolSz="1G"
    smallVolSz="5G"
    mediumVolSz="70G"
    largeVolSz="200G"

    #worker 1
        #journals
        qemu-img create "${path}/worker-1-135-1.qcow2" ${mediumVolSz} -f qcow2 -o preallocation=full
        qemu-img create "${path}/worker-1-135-2.qcow2" ${mediumVolSz} -f qcow2 -o preallocation=full
        #ledgers
        qemu-img create "${path}/worker-1-135-3.qcow2" ${largeVolSz} -f qcow2 -o preallocation=full
        qemu-img create "${path}/worker-1-135-4.qcow2" ${largeVolSz} -f qcow2 -o preallocation=full

        # small volumes
        qemu-img create "${path}/worker-1-135-5.qcow2" ${smallVolSz} -f qcow2 -o preallocation=full
        qemu-img create "${path}/worker-1-135-6.qcow2" ${smallVolSz} -f qcow2 -o preallocation=full
        qemu-img create "${path}/worker-1-135-7.qcow2" ${verySmallVolSz} -f qcow2 -o preallocation=full
        qemu-img create "${path}/worker-1-135-8.qcow2" ${verySmallVolSz} -f qcow2 -o preallocation=full

    #worker 2
        #journals
        qemu-img create "${path}/worker-2-135-1.qcow2" ${mediumVolSz} -f qcow2 -o preallocation=full
        qemu-img create "${path}/worker-2-135-2.qcow2" ${mediumVolSz} -f qcow2 -o preallocation=full
        #ledgers
        qemu-img create "${path}/worker-2-135-3.qcow2" ${largeVolSz} -f qcow2 -o preallocation=full
        qemu-img create "${path}/worker-2-135-4.qcow2" ${largeVolSz} -f qcow2 -o preallocation=full
        # small volumes
        qemu-img create "${path}/worker-2-135-5.qcow2" ${smallVolSz} -f qcow2 -o preallocation=full
        qemu-img create "${path}/worker-2-135-6.qcow2" ${smallVolSz} -f qcow2 -o preallocation=full
        qemu-img create "${path}/worker-2-135-7.qcow2" ${verySmallVolSz} -f qcow2 -o preallocation=full
        qemu-img create "${path}/worker-2-135-8.qcow2" ${verySmallVolSz} -f qcow2 -o preallocation=full

    #worker 3
        #journals
        qemu-img create "${path}/worker-3-135-1.qcow2" ${mediumVolSz} -f qcow2 -o preallocation=full
        qemu-img create "${path}/worker-3-135-2.qcow2" ${mediumVolSz} -f qcow2 -o preallocation=full
        #ledgers
        qemu-img create "${path}/worker-3-135-3.qcow2" ${largeVolSz} -f qcow2 -o preallocation=full
        qemu-img create "${path}/worker-3-135-4.qcow2" ${largeVolSz} -f qcow2 -o preallocation=full
        # small volumes
        qemu-img create "${path}/worker-3-135-5.qcow2" ${smallVolSz} -f qcow2 -o preallocation=full
        qemu-img create "${path}/worker-3-135-6.qcow2" ${smallVolSz} -f qcow2 -o preallocation=full
        qemu-img create "${path}/worker-3-135-7.qcow2" ${verySmallVolSz} -f qcow2 -o preallocation=full
        qemu-img create "${path}/worker-3-135-8.qcow2" ${verySmallVolSz} -f qcow2 -o preallocation=full

    #worker 4
        #journals
        qemu-img create "${path}/worker-4-135-1.qcow2" ${mediumVolSz} -f qcow2 -o preallocation=full
        qemu-img create "${path}/worker-4-135-2.qcow2" ${mediumVolSz} -f qcow2 -o preallocation=full
        #ledgers
        qemu-img create "${path}/worker-4-135-3.qcow2" ${largeVolSz} -f qcow2 -o preallocation=full
        qemu-img create "${path}/worker-4-135-4.qcow2" ${largeVolSz} -f qcow2 -o preallocation=full
        # small volumes
        qemu-img create "${path}/worker-4-135-5.qcow2" ${smallVolSz} -f qcow2 -o preallocation=full
        qemu-img create "${path}/worker-4-135-6.qcow2" ${smallVolSz} -f qcow2 -o preallocation=full
        qemu-img create "${path}/worker-4-135-7.qcow2" ${verySmallVolSz} -f qcow2 -o preallocation=full
        qemu-img create "${path}/worker-4-135-8.qcow2" ${verySmallVolSz} -f qcow2 -o preallocation=full

    # #worker 3 & 4
    #     qemu-img create "${path}/worker-3-135-1.qcow2" ${smallVolSz} -f qcow2 -o preallocation=full
    #     qemu-img create "${path}/worker-3-135-2.qcow2" ${smallVolSz} -f qcow2 -o preallocation=full
    #     qemu-img create "${path}/worker-3-135-3.qcow2" ${smallVolSz} -f qcow2 -o preallocation=full
    #     qemu-img create "${path}/worker-3-135-4.qcow2" ${verySmallVolSz} -f qcow2 -o preallocation=full
    #     qemu-img create "${path}/worker-3-135-5.qcow2" ${verySmallVolSz} -f qcow2 -o preallocation=full
    #     qemu-img create "${path}/worker-3-135-6.qcow2" ${verySmallVolSz} -f qcow2 -o preallocation=full

    #     qemu-img create "${path}/worker-4-135-1.qcow2" ${smallVolSz} -f qcow2 -o preallocation=full
    #     qemu-img create "${path}/worker-4-135-2.qcow2" ${smallVolSz} -f qcow2 -o preallocation=full
    #     qemu-img create "${path}/worker-4-135-3.qcow2" ${smallVolSz} -f qcow2 -o preallocation=full
    #     qemu-img create "${path}/worker-4-135-4.qcow2" ${verySmallVolSz} -f qcow2 -o preallocation=full
    #     qemu-img create "${path}/worker-4-135-5.qcow2" ${verySmallVolSz} -f qcow2 -o preallocation=full
    #     qemu-img create "${path}/worker-4-135-6.qcow2" ${verySmallVolSz} -f qcow2 -o preallocation=full
}