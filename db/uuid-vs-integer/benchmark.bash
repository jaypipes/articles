#! /usr/bin/env bash

this_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
run_dir=../../$this_dir
out_file=$this_dir/results.out
bench_args=${@:1}

truncate -s0 $out_file

for design in a b c; do
    base_cmd="sysbench --mysql-password=sbtest --schema-design=$design $bench_args db/uuid-vs-integer/brick-and-mortar.lua"
    echo "Using base command: $base_cmd" | tee -a $out_file
    echo "Resetting database for design $design" | tee -a $out_file
    $base_cmd cleanup &> /dev/null
    echo "Preparing database for design $design" | tee -a $out_file
    $base_cmd prepare >> $out_file
    echo "Running benchmark for design $design" | tee -a $out_file
    for threads in 1 2 4 8; do
        $base_cmd --threads=$threads run >> $out_file
    done
done
