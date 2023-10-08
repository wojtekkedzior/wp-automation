#!/bin/bash

function create() {
    path=$1
    for i in {1..2}
    do
        for j in {1..4}
        do
            echo "$path/worker-$i-$j.qcow2"
            qemu-img create "$path/worker-$i-$j.qcow2" 100G -f qcow2 -o preallocation=full
        done

        for j in {5..8}
        do
            echo "$path/worker-$i-$j.qcow2"
            qemu-img create "$path/worker-$i-$j.qcow2" 50G -f qcow2 -o preallocation=full
        done
    done
}


create /mnt/nvme/test