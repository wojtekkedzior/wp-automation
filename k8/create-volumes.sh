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
    smallVolSz="10G"

    #worker 1
        #journals
        qemu-img create "${path}/worker1-1.qcow2" 75G -f qcow2 -o preallocation=full
        qemu-img create "${path}/worker1-2.qcow2" 75G -f qcow2 -o preallocation=full
        #journals
        qemu-img create "${path}/worker1-3.qcow2" 600G -f qcow2 -o preallocation=full
        qemu-img create "${path}/worker1-4.qcow2" 600G -f qcow2 -o preallocation=full
        # small volumes
        qemu-img create "${path}/worker1-5.qcow2" ${smallVolSz} -f qcow2 -o preallocation=full
        qemu-img create "${path}/worker1-6.qcow2" ${smallVolSz} -f qcow2 -o preallocation=full

    #worker 2
        #journals
        qemu-img create "${path}/worker2-1.qcow2" 75G -f qcow2 -o preallocation=full
        qemu-img create "${path}/worker2-2.qcow2" 75G -f qcow2 -o preallocation=full
        #journals
        qemu-img create "${path}/worker2-3.qcow2" 600G -f qcow2 -o preallocation=full
        qemu-img create "${path}/worker2-4.qcow2" 600G -f qcow2 -o preallocation=full
        # small volumes
        qemu-img create "${path}/worker2-5.qcow2" ${smallVolSz} -f qcow2 -o preallocation=full
        qemu-img create "${path}/worker2-6.qcow2" ${smallVolSz} -f qcow2 -o preallocation=full

    #worker 3 & 4
        qemu-img create "${path}/worker3-1.qcow2" ${smallVolSz} -f qcow2 -o preallocation=full
        qemu-img create "${path}/worker3-2.qcow2" ${smallVolSz} -f qcow2 -o preallocation=full
        qemu-img create "${path}/worker3-3.qcow2" ${smallVolSz} -f qcow2 -o preallocation=full

        qemu-img create "${path}/worker4-1.qcow2" ${smallVolSz} -f qcow2 -o preallocation=full
        qemu-img create "${path}/worker4-2.qcow2" ${smallVolSz} -f qcow2 -o preallocation=full
        qemu-img create "${path}/worker4-3.qcow2" ${smallVolSz} -f qcow2 -o preallocation=full


    # for i in `eval echo {$workers_from..$workers_to}`;
    # do
    #     for j in `eval echo {1..$index}`;
    #     do
    #         echo "$path/worker-$i-$j.qcow2"
    #         qemu-img create "$path/worker-$i-$j.qcow2" 100G -f qcow2 -o preallocation=full
    #     done

    #     for j in `eval echo {$(( $index + 1 ))..6}`;
    #     do
    #         echo "$path/worker-$i-$j.qcow2"
    #         qemu-img create "$path/worker-$i-$j.qcow2" 5G -f qcow2 -o preallocation=full
    #     done
    # done
}

# create $1 $2 $3 $4