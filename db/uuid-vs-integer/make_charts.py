import csv
import os
import tempfile

dir_path = os.path.dirname(os.path.realpath(__file__))

SCENARIOS = (
    "order_counts_by_status",
    "lookup_orders_by_customer",
    "popular_items",
    "customer_new_order",
)

SIZES = ('small', 'medium', 'large')

DBSERVERS = ('MySQL', 'PostgreSQL')

if __name__ == '__main__':
    results_dir = os.path.join('../../', dir_path, 'results')
    out_dir = tempfile.mkdtemp()

    tpl = open('/home/jaypipes/tmp.html').read()

    print out_dir

    for db_server in DBSERVERS:
        for size in SIZES:
            for scenario in SCENARIOS:
                dbservernick = 'mysql'
                if db_server == 'PostgreSQL':
                    dbservernick = 'pgsql'
                csv_filepath = os.path.join(results_dir, 'results-%s-%s-%s.txt' %
                                        (dbservernick, scenario, size))
                data = []
                with open(csv_filepath, 'rb') as csv_file:
                    r = csv.reader(csv_file)
                    for x, row in enumerate(r):
                        if x == 0:
                            continue  # skip header
                        data.append(row)

                a0, a1, a2, a3, a4 = data[0]
                b0, b1, b2, b3, b4 = data[1]
                c0, c1, c2, c3, c4 = data[2]
                out_filepath = os.path.join(out_dir, '%s-%s-%s.html' %
                                            (scenario, dbservernick, size))
                title = scenario.replace('_', ' ').capitalize()
                with open(out_filepath, 'w+b') as out_file:
                    stamped = tpl.replace('$TITLE', title)
                    stamped = stamped.replace('$DBSERVER', db_server)
                    stamped = stamped.replace('$DBSIZE', size.capitalize())
                    stamped = stamped.replace('$A1', a1)
                    stamped = stamped.replace('$A2', a2)
                    stamped = stamped.replace('$A3', a3)
                    stamped = stamped.replace('$A4', a4)
                    stamped = stamped.replace('$B1', b1)
                    stamped = stamped.replace('$B2', b2)
                    stamped = stamped.replace('$B3', b3)
                    stamped = stamped.replace('$B4', b4)
                    stamped = stamped.replace('$C1', c1)
                    stamped = stamped.replace('$C2', c2)
                    stamped = stamped.replace('$C3', c3)
                    stamped = stamped.replace('$C4', c4)
                    out_file.write(stamped)
                    out_file.flush()
