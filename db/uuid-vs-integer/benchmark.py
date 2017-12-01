#! /usr/bin/env python

import csv
import os
import re
import subprocess
import sys
import tempfile

import MySQLdb

dir_path = os.path.dirname(os.path.realpath(__file__))

class MySQLCounters(object):
    def __init__(self):
        self.select_full_join = 0
        self.select_full_range_join = 0
        self.select_range = 0
        self.select_range_check = 0
        self.select_scan = 0
        self.sort_merge_passes = 0
        self.sort_range = 0
        self.sort_rows = 0
        self.sort_scan = 0
        self.handler_commit = 0
        self.handler_delete = 0
        self.handler_discover = 0
        self.handler_external_lock = 0
        self.handler_mrr_init = 0
        self.handler_prepare = 0
        self.handler_read_first = 0
        self.handler_read_key = 0
        self.handler_read_last = 0
        self.handler_read_next = 0
        self.handler_read_prev = 0
        self.handler_read_rnd = 0
        self.handler_read_rnd_next = 0
        self.handler_rollback = 0
        self.handler_savepoint = 0
        self.handler_savepoint_rollback = 0
        self.handler_update = 0
        self.handler_write = 0
        self.table_locks_immediate = 0
        self.table_locks_waited = 0
        self.created_tmp_disk_tables = 0
        self.created_tmp_files = 0
        self.created_tmp_tables = 0
        self.innodb_background_log_sync = 0
        self.innodb_buffer_pool_pages_data = 0
        self.innodb_buffer_pool_bytes_data = 0
        self.innodb_buffer_pool_pages_dirty = 0
        self.innodb_buffer_pool_bytes_dirty = 0
        self.innodb_buffer_pool_pages_flushed = 0
        self.innodb_buffer_pool_pages_free = 0
        self.innodb_buffer_pool_pages_lru_flushed = 0
        self.innodb_buffer_pool_pages_made_not_young = 0
        self.innodb_buffer_pool_pages_made_young = 0
        self.innodb_buffer_pool_pages_misc = 0
        self.innodb_buffer_pool_pages_old = 0
        self.innodb_buffer_pool_pages_total = 0
        self.innodb_buffer_pool_read_ahead_rnd = 0
        self.innodb_buffer_pool_read_ahead = 0
        self.innodb_buffer_pool_read_ahead_evicted = 0
        self.innodb_buffer_pool_read_requests = 0
        self.innodb_buffer_pool_reads = 0
        self.innodb_buffer_pool_wait_free = 0
        self.innodb_buffer_pool_write_requests = 0
        self.innodb_checkpoint_age = 0
        self.innodb_checkpoint_max_age = 0
        self.innodb_data_fsyncs = 0
        self.innodb_data_pending_fsyncs = 0
        self.innodb_data_pending_reads = 0
        self.innodb_data_pending_writes = 0
        self.innodb_data_read = 0
        self.innodb_data_reads = 0
        self.innodb_data_writes = 0
        self.innodb_data_written = 0
        self.innodb_dblwr_pages_written = 0
        self.innodb_dblwr_writes = 0
        self.innodb_ibuf_free_list = 0
        self.innodb_ibuf_segment_size = 0
        self.innodb_log_waits = 0
        self.innodb_log_write_requests = 0
        self.innodb_log_writes = 0
        self.innodb_lsn_current = 0
        self.innodb_lsn_flushed = 0
        self.innodb_lsn_last_checkpoint = 0
        self.innodb_master_thread_active_loops = 0
        self.innodb_master_thread_idle_loops = 0
        self.innodb_max_trx_id = 0
        self.innodb_mem_adaptive_hash = 0
        self.innodb_mem_dictionary = 0
        self.innodb_oldest_view_low_limit_trx_id = 0
        self.innodb_os_log_fsyncs = 0
        self.innodb_os_log_pending_fsyncs = 0
        self.innodb_os_log_pending_writes = 0
        self.innodb_os_log_written = 0
        self.innodb_page_size = 0
        self.innodb_pages_created = 0
        self.innodb_pages_read = 0
        self.innodb_pages_written = 0
        self.innodb_purge_trx_id = 0
        self.innodb_purge_undo_no = 0
        self.innodb_row_lock_current_waits = 0
        self.innodb_row_lock_time = 0
        self.innodb_row_lock_time_avg = 0
        self.innodb_row_lock_time_max = 0
        self.innodb_row_lock_waits = 0
        self.innodb_rows_deleted = 0
        self.innodb_rows_inserted = 0
        self.innodb_rows_read = 0
        self.innodb_rows_updated = 0
        self.innodb_num_open_files = 0
        self.innodb_truncated_status_writes = 0
        self.innodb_available_undo_logs = 0
        self.innodb_secondary_index_triggered_cluster_reads = 0
        self.innodb_secondary_index_triggered_cluster_reads_avoided = 0

    @classmethod
    def get(cls):
        obj = cls()
        db = MySQLdb.connect(host="localhost", user="sbtest", passwd="sbtest", db="sbtest")
        cur = db.cursor()
        cur.execute("SHOW GLOBAL STATUS")
        for row in cur.fetchall():
            key = row[0].lower()
            val = row[1]
            if hasattr(obj, key):
                setattr(obj, key, int(val))
        cur.close()
        return obj

    def out(self, only_nonzero=False):
        for k, v in self.__dict__.items():
            if only_nonzero and v == 0:
                continue
            print k, v


def get_mysql_counter_deltas(start, end):
    res = MySQLCounters()
    for k, v in end.__dict__.items():
        delta = v - getattr(start, k)
        setattr(res, k, delta)
    # MySQL performs some operations for the actual SHOW GLOBAL STATUS call,
    # which we remove here from the deltas...
    res.select_scan = res.select_scan - 2
    res.handler_read_rnd_next = res.handler_read_rnd_next - 782
    res.created_tmp_tables = res.created_tmp_tables - 1
    res.table_locks_immediate = res.table_locks_immediate - 1
    res.handler_external_lock = res.handler_external_lock - 2
    res.handler_write = res.handler_write - 390
    return res


SB_TPS_RE = re.compile(r'.*transactions:.*\((\d+\.\d+) per sec', re.M)
def get_tps_from_sysbench_output(output):
    match = SB_TPS_RE.search(output)
    if match:
        return float(match.group(1))


class BenchResult(object):
    def __init__(self, schema_design, scenario, size, threads):
        self.schema_design = schema_design
        self.scenario = scenario
        self.threads = threads
        self.size = size
        self.tps = 0
        self.stats_diff = None


SCHEMA_DESIGNS = {
    "a": "Auto-inc PK only",
    "b": "UUID PK only",
    "c": "Auto-inc PK, UUID external",
}

SCENARIOS = (
    "order_counts_by_status",
    "lookup_orders_by_customer",
    "popular_items",
    "customer_new_order",
)

SIZES = {
    'small': [
        '--num-orders=2000',
        '--min-order-items=2',
        '--max-order-items=2',
    ],
    'medium': [
        '--num-orders=7000',
        '--min-order-items=3',
        '--max-order-items=3',
    ],
    'large': [
        '--num-orders=100000',
        '--min-order-items=10',
        '--max-order-items=10',
    ],
}

if __name__ == '__main__':
    run_dir = os.path.join('../..', dir_path)
    result_dir = tempfile.mkdtemp()
    result_filepath = os.path.join(result_dir, 'results.out')
    result_file = open(result_filepath, 'w+b')

    results = []

    def tee(message, no_newline=False):
        nl = "\n"
        if no_newline:
            nl = ""
        result_file.write(message + nl)
        sys.stdout.write(message + nl)
        sys.stdout.flush()

    print "Writing to %s" % result_dir

    for design, design_description in SCHEMA_DESIGNS.items():
        for size, size_args in SIZES.items():
            base_cmd = [
                'sysbench',
                '--mysql-password=sbtest',
                '--time=30',
                '--schema-design=%s' % design,
                'db/uuid-vs-integer/brick-and-mortar.lua',
            ] + size_args + sys.argv[1:]
            tee("============================== START BENCH %s [%s] (size: %s)=============================" %
                (design, design_description, size))
            tee("Using base command: %s" % " ".join(base_cmd))
            tee("Resetting database for %s (size %s) " % (design, size))
            subprocess.call(base_cmd + ['cleanup'], stdout=result_file)
            tee("Restarting DB server and clearing all logs and data files")
            subprocess.call(['systemctl', 'stop', 'mysql'], stdout=result_file)
            subprocess.call(['rm', '-rf', '/var/lib/mysql/ib_logfile*'], stdout=result_file)
            subprocess.call(['systemctl', 'start', 'mysql'], stdout=result_file)
            tee("Preparing database for %s (size %s) " % (design, size))
            subprocess.call(base_cmd + ['prepare'], stdout=result_file)
            for scenario in SCENARIOS:
                for threads in (1, 2, 4, 8):
                    res = BenchResult(design, scenario, size, threads)
                    tee("Running %s scenario for %s (size %s w/ %d threads) ... " %
                        (scenario, design, size, threads),
                        no_newline=True)
                    start = MySQLCounters.get()
                    run_out = subprocess.check_output(base_cmd +
                                                      ['--threads=%d' %
                                                       threads, '--scenario=%s'
                                                       % scenario, 'run'],
                                                      stderr=subprocess.STDOUT)
                    res.tps = get_tps_from_sysbench_output(run_out)
                    tee("%.2f tps" % res.tps)
                    end = MySQLCounters.get()
                    diff = get_mysql_counter_deltas(start, end)
                    res.stats_diff = diff
                    results.append(res)
            tee("============================== END BENCH %s [%s] (size: %s)=============================" %
                (design, design_description, size))

    for scenario in SCENARIOS:
        for size in SIZES.keys():
            csv_filepath = os.path.join(result_dir, 'results-%s-%s.txt' % (scenario, size))
            csv_file = open(csv_filepath, 'w+b')
            csv_writer = csv.writer(csv_file)
            csv_writer.writerow(["design", "1 thread", "2 threads", "4 threads", "8 threads"])
            for design in sorted(SCHEMA_DESIGNS.keys()):
                batch = [
                    r for r in results
                    if r.size == size
                    and r.schema_design == design
                    and r.scenario == scenario
                ]
                batch = sorted(batch, key=lambda x: x.threads)
                cols = [design] + [r.tps for r in batch]
                csv_writer.writerow(cols)
            csv_file.flush()
            csv_file.close()
