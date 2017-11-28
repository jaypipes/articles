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
    echo "Restarting DB server and clearing all logs and data files"
    systemctl stop mysql
    rm -rf /var/lib/mysql/ib_logfile*
    systemctl start mysql
    ls -l /var/lib/mysql/ib* | tee -a $out_file
    echo "Grabbing MySQL status numbers before prepare"
    mysql --user=sbtest --password=sbtest -N -e"SHOW GLOBAL STATUS LIKE 'Select%'" 2>/dev/null | tee -a $out_file
    mysql --user=sbtest --password=sbtest -N -e"SHOW GLOBAL STATUS LIKE 'Sort%'" 2>/dev/null | tee -a $out_file
    mysql --user=sbtest --password=sbtest -N -e"SHOW GLOBAL STATUS LIKE 'Handler%'" 2>/dev/null | tee -a $out_file
    mysql --user=sbtest --password=sbtest -N -e"SHOW GLOBAL STATUS LIKE 'Table%'" 2>/dev/null | tee -a $out_file
    mysql --user=sbtest --password=sbtest -N -e"SHOW GLOBAL STATUS LIKE 'Created%'" 2>/dev/null | tee -a $out_file
    mysql --user=sbtest --password=sbtest -N -e"SHOW GLOBAL STATUS LIKE 'Innodb%'" 2>/dev/null | tee -a $out_file
    echo "Preparing database for design $design" | tee -a $out_file
    $base_cmd prepare >> $out_file
    for scenario in customer_new_order lookup_orders_by_customer popular_items; do
        echo "Running benchmark $scenario for design $design" | tee -a $out_file
        echo "Grabbing MySQL status numbers before run"
        mysql --user=sbtest --password=sbtest -N -e"SHOW GLOBAL STATUS LIKE 'Select%'" 2>/dev/null | tee -a $out_file
        mysql --user=sbtest --password=sbtest -N -e"SHOW GLOBAL STATUS LIKE 'Sort%'" 2>/dev/null | tee -a $out_file
        mysql --user=sbtest --password=sbtest -N -e"SHOW GLOBAL STATUS LIKE 'Handler%'" 2>/dev/null | tee -a $out_file
        mysql --user=sbtest --password=sbtest -N -e"SHOW GLOBAL STATUS LIKE 'Table%'" 2>/dev/null | tee -a $out_file
        mysql --user=sbtest --password=sbtest -N -e"SHOW GLOBAL STATUS LIKE 'Created%'" 2>/dev/null | tee -a $out_file
        mysql --user=sbtest --password=sbtest -N -e"SHOW GLOBAL STATUS LIKE 'Innodb%'" 2>/dev/null | tee -a $out_file
        for threads in 1 2 4 8; do
            $base_cmd --scenario=$scenario --threads=$threads run >> $out_file
        done
        echo "Grabbing MySQL status numbers after run"
        mysql --user=sbtest --password=sbtest -N -e"SHOW GLOBAL STATUS LIKE 'Select%'" 2>/dev/null | tee -a $out_file
        mysql --user=sbtest --password=sbtest -N -e"SHOW GLOBAL STATUS LIKE 'Sort%'" 2>/dev/null | tee -a $out_file
        mysql --user=sbtest --password=sbtest -N -e"SHOW GLOBAL STATUS LIKE 'Handler%'" 2>/dev/null | tee -a $out_file
        mysql --user=sbtest --password=sbtest -N -e"SHOW GLOBAL STATUS LIKE 'Table%'" 2>/dev/null | tee -a $out_file
        mysql --user=sbtest --password=sbtest -N -e"SHOW GLOBAL STATUS LIKE 'Created%'" 2>/dev/null | tee -a $out_file
        mysql --user=sbtest --password=sbtest -N -e"SHOW GLOBAL STATUS LIKE 'Innodb%'" 2>/dev/null | tee -a $out_file
    done
    ls -l /var/lib/mysql/ib* | tee -a $out_file
done
