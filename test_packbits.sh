#!/bin/bash

mkdir -p test_results

echo "n,workload,intrinsics,status,cycles,instructions,ipc" > test_results/results.csv

for i in 0 1; do
    for workload in 0 2 4 8 16 32; do
    # for workload in 0 2 4; do
        rm -f /vortex/tests/regression/packBits/config.h
        touch /vortex/tests/regression/packBits/config.h
        if [ $i -eq 1 ]; then
            echo "#define PACK_BITS_INTRINSICS" > /vortex/tests/regression/packBits/config.h
            echo "PACK_BITS_INTRINSICS"
        fi
        if [ $workload -ne 0 ]; then
            echo "#define WORK_LOAD_PER_THREAD $workload" >> /vortex/tests/regression/packBits/config.h
            echo "WORK_LOAD_PER_THREAD $workload"
        fi
        ../configure --tooldir=$HOME/tools
        make -C tests/regression/packBits clean
        make -C tests/regression/packBits
        for n in 32 64 128 256 512 1024 2048 4096 8192 16384; do
            echo "Testing n=$n"

            output=$(./ci/blackbox.sh --app=packBits --args="-n$n" 2>&1)
            status=$?
            
            cycles=$(echo "$output" | grep "PERF:" | sed -n 's/.*cycles=\([0-9]*\).*/\1/p')
            instructions=$(echo "$output" | grep "PERF:" | sed -n 's/.*instrs=\([0-9]*\).*/\1/p')
            ipc=$(echo "$output" | grep "PERF:" | sed -n 's/.*IPC=\([0-9.]*\).*/\1/p')
            
            cycles=${cycles:-"N/A"}
            instructions=${instructions:-"N/A"}
            ipc=${ipc:-"N/A"}
            
            echo "$n,$workload,$i,$(if [ $status -eq 0 ]; then echo "PASS"; else echo "FAIL"; fi),$cycles,$instructions,$ipc" >> test_results/results.csv
            
            echo "$output" > "test_results/n${n}_w${workload}_i${i}.log"
        done
    done
done

echo "All tests completed. Results are in test_results/results.csv" 