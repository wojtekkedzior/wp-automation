#!/bin/bash

function create() {
    path=$1
    for i in {1..2}
    do
        for j in {1..2}
        do
            echo "$path/worker-$i-$j.qcow2"
            qemu-img create "$path/worker-$i-$j.qcow2" 100G -f qcow2 -o preallocation=full
        done

        for j in {3..8}
        do
            echo "$path/worker-$i-$j.qcow2"
            qemu-img create "$path/worker-$i-$j.qcow2" 20G -f qcow2 -o preallocation=full
        done
    done
}

create $1