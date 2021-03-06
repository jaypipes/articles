# Investigation into UUID vs. integer database performance

There have [been](http://kccoder.com/mysql/uuid-vs-int-insert-performance/) [a](https://cjsavage.com/guides/mysql/insert-perf-uuid-vs-ordered-uuid-vs-int-pk.html) [number](https://tomharrisonjr.com/uuid-or-guid-as-primary-keys-be-careful-7b2aa3dcb439) [of](http://krow.livejournal.com/497839.html) [articles](https://www.percona.com/blog/2007/03/13/to-uuid-or-not-to-uuid/) over the past ten years or so that
describe some of the benefits, costs and potential pitfalls of using UUID
values as primary keys for database tables instead of the more traditional
auto-incrementing integer primary key.

Each of these articles tends to include some interesting graphs, but nearly all
of them focus on two metrics for benchmark data: the raw speed of `INSERT`
statements and the size of the table data and index data segments. While these
metrics are both very important, focusing on them exclusively leaves out a
number of critical points from the overall discussion of application
performance, scaling strategies and query efficiency.

In addition, most of the articles I've read look strictly at [MySQL](https://www.mysql.com) (and InnoDB
storage engine) performance and don't touch the other great open source
database server, [PostgreSQL](https://postgresql.org).

In this article, I  aim to provide a thorough data-backed comparison of UUID
and integer field performance for both MySQL and PostgreSQL. We'll be examining
a schema that represents a real-world application and run a series of
comparative benchmark scenarios that demonstrate the impact of using one
strategy over another.

1. [Overview](#overview)
    1. [On external identifiers](#on-external-identifiers)
    1. [Scaling considerations](#scaling-considerations)
1. [Database schema](#database-schema)
    1. [UUID column type considerations](#uuid-column-type-considerations)
1. [Schema design strategies](#schema-design-strategies)
    1. [A: Auto-inc integer PK, no UUIDs](#schema-design-a-auto-incrementing-integer-primary-key-no-uuids)
    1. [B: UUID PK](#schema-design-b-uuid-primary-key)
    1. [C: Auto-inc integer PK, external UUIDs](#schema-design-c-auto-incrementing-integer-primary-key-uuid-externals)
1. [Application scenarios](#application-scenarios)
    1. [New customer order](#new-customer-order)
    1. [Lookup customer orders](#lookup-customer-orders)
    1. [Order counts by status](#order-counts-by-status)
    1. [Lookup most popular items](#lookup-most-popular-items)
1. [Test configuration](#test-configuration)
    1. [Hardware setup](#hardware-setup)
    1. [Benchmark variants](#benchmark-variants)
    1. [DB setup](#db-setup)
1. [Benchmark results](#benchmark-results)
    1. [New customer order](#new-customer-order-results)
    1. [Lookup customer orders](#lookup-customer-orders-results)
    1. [Order counts by status](#order-counts-by-status-results)
    1. [Lookup most popular items](#lookup-most-popular-items-results)
1. [Conclusions](#conclusions)

## Overview

When designing a relational database schema, application developers have to
decide what the **primary key** of each table should be. Some developers choose
a "natural primary key" that may exist for some entity -- e.g. a phone number
might be a good natural primary key for an employee entity. Other developers
choose what is called a "synthetic primary key", which is a number or string of
characters that is either sequentially or randomly generated.

This article will focus on assessing the impact of column type for developers
making the latter choice to use a synthetic primary key for their entities.
These developers typically choose to use either a sequentially-generated
integer or a randomly-generated UUID value as their primary key column type.

### On external identifiers

There are some *non* performance-related differences between integer and UUID
primary keys that are worth noting.

When it comes to how end users interact with the application -- and ultimately
with the relational database that backs that application -- there's a pretty
stark difference between applications that use integer vs UUID values as
**their external identifiers**. One might reasonably argue that a URL like
`https://example.com/products/123456` is more user-friendly and readable than a
URL that looks like
`https://example.com/products/27da46fb-f4c3-449e-bfc3-c2523ffeeebc`.

On the flip side, one might reasonably argue that having a
sequentially-incrementing integer primary key as your application's external
identifier can have negative side-effects:

* Competitors can trivially determine the number of customers or sales orders
  that you have
* Crackers can piece together a critical part of customer information since
  identifiers are sequential and guessable

### Scaling considerations

When an application grows beyond the ability of a single database server or
cluster to service user needs, the application development team must figure out
how to **scale out** the application.

The most traditional and popular way of scaling out an application is to use a
**partitioning** or **sharding** strategy. The application database is cloned
into an application shard and that shard services a portion of the user
requests. While an in-depth discussion of the issues developers run into when
sharding their applications is beyond the scope of this article, it's important
to address one glaring issue that arises from using sequentially-incrementing
integers as **external identifiers** for an application.

Using sequentially-incrementing integers as external identifiers and primary
keys leads to trouble when attempting to shard an application for scale-out.
When cloning the application database for the new application shard, external
identifiers produced in the new shard will duplicate external identifiers from
the first shard unless the application developers use one of two strategies to
prevent this duplication.

One strategy is to take extreme care to set the starting integer sequence of
the new shard's database tables to a high value leaving room for the original
shard's incrementing identifier sequences to continue to grow as needed.
Unfortunately, each time a new shard is brought online, the same problem will
arise and the application development team will need to play the dance of
manually carving out enough space in each shard for new integer primary keys in
the shard.

The other strategy would be to have users pass a "shard key" in *addition to
the external identifier* so that top-level application routers will be able to
determine which application shard to send a request to. For example, if each
shard contains a customers table that uses a sequentially-generated integer
primary key as the customer's external identifier, then an additional shard or
partition key will be needed by the top-level application router to determine
which shard to send a request for customer "123456" since both shard databases
could have "123456" as a primary key in their customers table. So the end user
might end up having to manually specify shard "A" along with their external
identifier of "123456". Clearly this is neither ideal nor user-friendly.

UUIDs as external identifiers eliminate the above issues with regard to scaling
out via sharding. Since UUIDs are, well, universal, there's no need to worry
about duplicate external identifiers.

**NOTE**: [Schema design "C"](#schema-design-c-auto-incrementing-integer-primary-key-external-uuids) discussed below is specially designed to benchmark
the performance of a database schema that uses UUID values for **external**
identifiers and sequentially-generated integers for **internal** primary keys.
This database schema doesn't suffer from the scale-out issues that arise from
using sequentially-generated integers as external identifiers.

## Database schema

Many real-world applications show similar patterns with regards to the types of
queries that are common for the particular category of application.

For example, point-of-sale and work order management systems tend to have
mostly rigid search queries -- find products with a particular SKU or the work
orders for a customer having a specific phone number.

Customer relationship management (CRM) and enterprise resource planning (ERP)
applications tend to feature search capabilities that are either free-form
(fulltext) or allow the user to search for records based on some well-defined
relationship -- for instance, find all the wholesalers that have a reseller
arrangement with some set of suppliers.

When it comes to the performance of any particular query, it's important to
consider the query in the context of the application in which it runs. That's
why this article uses an archetypal point-of-sale application in order to
illustrate real-world application query patterns. Instead of relying on
synthetic tables that don't represent actual data access patterns, we'll
examine queries that would actually be run against a real application and
examine the impact of using UUIDs versus integer columns on these queries.

To explore all the data access patterns I wanted to explore, I created a
"brick-and-mortar" store point-of-sale application. This application is all
about recording information for an imaginary home-goods store: orders,
customers, suppliers, products, etc.

![brick-and-mortar store E-R diagram](uuid-vs-integer/images/brick-and-mortar-e-r.png "Entity-relationship diagram for brick-and-mortar store application")

### UUID column type considerations

For UUID generation, I used a [Lua module](uuid-vs-integer/uuid.lua) that, with [some hacking](uuid-vs-integer/brick-and-mortar.lua#L1817-L1820) to support
thread-safe operations, generated UUIDs in a consistent fashion for each thread
executing. This allowed me to compare the impact of UUID vs integer primary
keys with permutations in initial database size.

For defining the UUID columns in MySQL, I went with a `CHAR(36)` column type.

I'm aware that there are various suggestions for making more efficient UUID
storage, including using a `BINARY(16)` column type or a `CHAR(32)` column
type (after stripping the '-' dash characters from the typical string UUID
representation). However, in my experience either `CHAR(36)`  or `VARCHAR(36)`
column types, with the dashes kept in the stored value, is the most common
representation of UUIDs in a MySQL database, and that's what I chose to compare
to.

Since PostgreSQL has a native UUID type, I used that column type and since
sysbench doesn't currently support native UUID parameter type binding, I used
the `CAST(? AS UUID)` expression to convert the string UUID to a native
PostgreSQL UUID type where necessary.

## Schema design strategies

There are three different strategies for database schema design that we wish to
examine in this article:

* Schema design A: Auto-incrementing integer primary key, no UUIDs
* Schema design B: UUID primary key
* Schema design C: Auto-increment integer primary key, external UUIDs

### Schema design A: Auto-incrementing integer primary key, no UUIDs

Schema Design "A" represents a database design strategy that **_only_** uses
auto-incrementing integers as primary keys. Application users look up entities
by using this auto-incrementing integer as the identifier for various objects
in the system.

For [MySQL](https://github.com/jaypipes/articles/blob/master/db/uuid-vs-integer/brick-and-mortar.lua#L34-L124), this means that tables in the application schemas are all defined
with an `id` column as the primary key in the following manner:

```sql
CREATE TABLE products (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  ...
);
```

For [PostgreSQL](https://github.com/jaypipes/articles/blob/master/db/uuid-vs-integer/brick-and-mortar.lua#L125-L235), this means tables in the application schemas are all defined
with an `id` column as the primary key in the following manner:

```sql
CREATE TABLE products (
  id SERIAL NOT NULL PRIMARY KEY,
  ...
);
```

### Schema design B: UUID primary key

Schema Design "B" represents a database design strategy that **_only_** uses a
UUID column for the primary key of various entities. Application users use the
UUID as record identifiers.

For [MySQL](https://github.com/jaypipes/articles/blob/master/db/uuid-vs-integer/brick-and-mortar.lua#L237-L326), this means that tables in the application schemas are all defined
with a `uuid` column as the primary key in the following manner:

```sql
CREATE TABLE products (
  uuid CHAR(36) NOT NULL PRIMARY KEY,
  ...
);
```

For [PostgreSQL](https://github.com/jaypipes/articles/blob/master/db/uuid-vs-integer/brick-and-mortar.lua#L327-L437), this means tables in the application schemas are all defined
with an `uuid` column as the primary key in the following manner:

```sql
CREATE TABLE products (
  uuid UUID NOT NULL PRIMARY KEY,
  ...
);
```

**NOTE**: PostgreSQL has a native UUID type.

### Schema design C: Auto-incrementing integer primary key, UUID externals

Schema Design "C" represents a database design strategy that uses
auto-incrementing integers as the primary key for entities, but these integer
keys are not exposed to users. Instead, UUIDs are used as the identifiers that
application users utilize to look up specific records in the application.

In other words, there is a secondary unique constraint/key on a UUID column for
each table in the schema.

For [MySQL](https://github.com/jaypipes/articles/blob/master/db/uuid-vs-integer/brick-and-mortar.lua#L439-L535), this means that tables in the application schemas are all defined
with an `id` column as the primary key and a `uuid` secondary key in the
following manner:

```sql
CREATE TABLE products (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  uuid CHAR(36) NOT NULL,
  ...
  UNIQUE INDEX uix_uuid (uuid)
);
```

For [PostgreSQL](https://github.com/jaypipes/articles/blob/master/db/uuid-vs-integer/brick-and-mortar.lua#L537-L670), this means that tables in the application schemas are all
defined with an `id` column as the primary key and a `uuid` secondary key in
the following manner:

```sql
CREATE TABLE products (
  id SERIAL NOT NULL PRIMARY KEY,
  uuid UUID NOT NULL UNIQUE,
  ...
);
```

**NOTE**: PostgreSQL has a native UUID type.

## Application scenarios

I wanted to show the impact of these schema designs/choices in **real-world
applications**. To that point, I developed a number of benchmark scenarios that
I thought represented some realistic data access and data write patterns.

For the brick-and-mortar application, I came up with these scenarios:

* New customer order
* Lookup customer orders
* Order counts by status
* Lookup most popular items

Following is an explanation of each scenario and the SQL statements from which
the scenario is composed.

### New customer order

The `customer_new_order` scenario emulates a single customer making a purchase
of items in the store. The steps involved are:

1. Look up some random products that have inventory at the store
1. (Schema design "C" only) Look up the customer's internal ID from their
   external UUID
1. Begin a transaction
1. Create an order record for the customer
1. (Schema design "A" and "C" only) Get the newly-inserted internal ID of the
   order
1. For each selected product:
    1. Look up a fulfilling supplier for the product
    1. Look up the current price of the product
    1. Create an order item record for the product and supplier on the order
1. Commit the transaction

This scenario is designed to stress both the `INSERT` performance for
multi-table transactions as well as read performance on a table scan (since we
purposely have no index used when ordering by `RAND()` when looking up products
for the customer to purchase).

This `customer_new_order` scenario is different from other synthetic `INSERT`
benchmarks you may have seen in other articles in a **few important ways**:

* We are mixing reads and writes in a single transaction, which is more
  representative of a real-world scenario
* For schema design "C", we accurately stress the impact of needing to do one
  additional "point select" query for grabbing the internal customer ID from
  the external customer UUID
* For schema designs "A" and "C", the scenario accurately represents the need
  to perform an additional query to retrieve the newly-created order's
  auto-incrementing primary key before inserting order detail records. This step
  does not need to be done for schema design "B" since the UUID is generated
  ahead of order record creation and it is important to account for this
  difference when we benchmark

### Lookup customer orders

The `lookup_orders_by_customer` scenario is designed to emulate a query that
would be run by a customer service representative when a customer comes into
the store and needs to find some information on their recent orders.

This scenario only entails a single `SELECT` query, but the query is designed
to stress a particular archetypal data access pattern: aggregating information
across a set of columns in a fact table while filtering records on a secondary
index in that fact table.

This query looks like this for schema design "A":

```sql
SELECT
 o.id,
 o.created_on,
 o.status,
 COUNT(*) AS num_items,
 SUM(od.quantity * od.price) AS total_amount
FROM orders AS o
JOIN order_details AS od
 ON o.id = od.order_id
WHERE o.customer_id = ?
GROUP BY o.id
ORDER BY o.created_on DESC
```

for schema design "B", the query is as follows:

```sql
SELECT
 o.uuid,
 o.created_on,
 o.status,
 COUNT(*) AS num_items,
 SUM(od.quantity * od.price) AS total_amount
FROM orders AS o
JOIN order_details AS od
 ON o.uuid = od.order_uuid
WHERE o.customer_uuid = ?
GROUP BY o.uuid
ORDER BY o.created_on DESC
```

and finally, for schema design "C", the query looks like this:

```sql
SELECT
 o.uuid,
 o.created_on,
 o.status,
 COUNT(*) AS num_items,
 SUM(od.quantity * od.price) AS total_amount
FROM orders AS o
JOIN order_details AS od
 ON o.id = od.order_id
JOIN customers AS c
 ON o.customer_id = c.id
WHERE c.uuid = ?
GROUP BY o.id
ORDER BY o.created_on DESC
```

**NOTE**: For schema design "C", since we use the UUID as the external
identifier for the customer, we need to join to the `customers` table in order
to query on the customer's UUID value. Since the UUID *is* the primary key in
schema design "B" and the auto-incrementing integer *is* the primary key in
schema design "A", those queries **do not need to join** to the `customers` table.

### Order counts by status

The `order_counts_by_status` scenario also includes a single `SELECT` statement
that is exactly the same for each schema design:

```sql
SELECT o.status, COUNT(*) AS num_orders
FROM orders AS o
GROUP BY o.status
```

There is a secondary index on the `orders.status` table, so this particular
scenario is testing the impact of using UUIDs vs integer primary keys when the
only column being used in an aggregate query **_is not the primary key_** and there
is an index on that field.

For MySQL with InnoDB, which uses a clustered index organized table layout,
this means that each secondary index record **_also includes the primary key_** as
well.

With the `order_counts_by_status`, we will be able to determine the impact of
primary key column type choice even for queries that seemingly do not involve
those primary keys.

### Lookup most popular items

The `lookup_most_popular_items` scenario also features a single `SELECT`
statement that might be run by an extract-transform-load (ETL) tool or an
online analytical processing (OLAP) program.

For the general manager of our brick-and-mortar store, she might want to know
which are the best-selling products and which suppliers are providing those
products.

The `SELECT` expression for this query looks like this:

```sql
SELECT
 p.name,
 s.name,
 COUNT(DISTINCT o.id) AS included_in_orders,
 SUM(od.quantity * od.price) AS total_purchased
FROM orders AS o
JOIN order_details AS od
 ON o.id = od.order_id
JOIN products AS p
 ON od.product_id = p.id
JOIN suppliers AS s
 ON od.fulfilling_supplier_id = s.id
GROUP BY p.id, s.id
ORDER BY COUNT(DISTINCT o.id) DESC
LIMIT 100
```

**NOTE**: There is no `WHERE` clause on the above, which means that there will
end up being a full table scan of the `order_details`. I've specifically
designed this query to show the impact that the choice of using UUID or
auto-incrementing primary keys has on **_sequential read performance_**.

## Test configuration

### Hardware and operating system setup

Some information about the hardware and platform used for the benchmarking:

* Single-processor system with an Intel Core i7 CPU @ 3.33GHz - 6 cores, 12 threads
* 24GB RAM
* Running Linux kernel 4.8.0-59-generic

All benchmarks were run overnight when nothing other than the benchmarks (and
the DB server of course) were running on the machine.

### Benchmark variants

All benchmark runs were done using sysbench 1.0.12, with **_30 seconds_** run
time for each scenario variation. The one scenario that writes records to a
table (`customer_new_order`) was run **_after_** the scenarios that only read
records. This was to ensure consistent results that were able to be compared
between different initial sizes of database.

For the brick-and-mortar application, I tested three sizes -- "small", "medium"
and "large" -- of databases. The "small" size was pre-loaded with approximately
4000 order detail records. The "medium" had around 21000 order detail records
and the "large" had around 1M order detail records. I did this to see the
relative impact of the base fact table (`order_details`) on the performance of
various operations.

Of course, 1M order detail records isn't a "large" database at all.

However, the sizing here is only relative to each other. The medium database is
approximately an order of magnitude greater than the small database. And the
large database is another order of magnitude greater than the medium.

It's worth noting that for the MySQL tests, the "large" database size
represented an `order_details` table that was greater than the total size of
the InnoDB buffer pool used by the server (128MB). You will note the impact of
exhausting the buffer pool and needing to spool records off disk in some of the
benchmarks below. You will see the impact of the database design and column
type choices on that unfortunate situation as well!

The benchmark script was written in Lua and is [included](uuid-vs-integer/brick-and-mortar.lua) in this article
repository for anyone to take a look at and critique. If you find errors,
please create an [issue](https://github.com/jaypipes/articles/issues) on Github and/or submit a pull request with a fix and I
will re-run anything as needed and publish errata accordingly.

### DB configuration

The database server configurations we test are the following:

* MySQL Server 5.7.19-17 using the default InnoDB storage engine
* PostgreSQL 9.5.7

**The DB configurations were completely stock**.

I made no adjustments for the purposes of tuning or anything else. The MySQL
`innodb_buffer_pool_size` was 128MB (the default). Besides needing to create a
database user in MySQL and PostgreSQL, I issued zero SQL statements outside of
those executed by the benchmark scenarios themselves.

## Benchmark results

Below, for each data access/write scenario, I give the results for the various
database sizes tested for both MySQL and PostgreSQL.

Note that **_I'm not comparing MySQL and PostgreSQL here_**.

That's not the point of interest in these benchmarks. Instead, I'm interested
in seeing the impact on each database server's performance when using UUIDs vs
auto-incrementing integers for primary keys.

Also note that I did **_no tuning or optimization whatsoever_** for either MySQL or
PostgreSQL. Again, the point is to identify the impact of primary key column
type choice on the performance of a variety of data write and read patterns.
The point of this benchmark is **not** to tune a particular database for a specific
workload or compare MySQL to PostgreSQL.

The CSV files containing the parsed results of the sysbench runs are [available](uuid-vs-integer/results/)
in this article git repository.

Results for each scenario are shown below in separate sections. For each
scenario, I show a bar graph visualization of the results, the raw results in
tabular format, followed by a table showing the differences in performance
between schema design "A" and schema designs "B" and "C" for that particular
scenario and initial database size.

**NOTE**: In the tables showing the performance differences between schema
design "A" and schema designs "B" and "C", you will note that I included ![red]
red, ![org] orange or ![grn] green boxes. These boxes have the following meaning:

| color  | difference between schema "A" results                                 |
| ------ | --------------------------------------------------------------------- |
| ![grn] | less then 5% negative difference (including all positive differences) |
| ![org] | between 5% and 14.99% negative difference                             |
| ![red] | 15% or greater negative difference                                    |

### New customer order results

Here are the number of transactions per second that were possible (for N
concurrent threads) for the [`customer_new_order`](#new-customer-order) scenario. These transactions
are the number of new customer orders (including all order details) that could
be created per second. This event entails reads from a number of tables,
including `products` and `product_price_history` as well as writes to multiple
tables within a single transaction.

#### `customer_new_order` TPS / MySQL / Small DB size

![New customer orders - MySQL - small DB](uuid-vs-integer/images/customer_new_order-mysql-small.png "MySQL - Small DB - New customer order transactions per second")

| Schema design                     |       1      |       2     |     4       |     8       |
| --------------------------------- | ------------:| -----------:| -----------:| -----------:|
| A (auto-increment PKs no UUID)    |       193.33 |      416.24 |      854.21 |     1646.86 |
| B (UUID PKs only)                 |       131.45 |      293.09 |      650.58 |     1160.55 |
| C (auto-increment PK, ext UUID)   |       164.73 |      418.32 |      775.80 |     1389.74 |

The following table shows the differences in TPS compared to schema design "A".

| Schema design                     |   1            |   2            |    4           |      8         |
| --------------------------------- | --------------:| --------------:| --------------:| --------------:|
| B (UUID PKs only)                 | ![red] -32.00% | ![red] -29.58% | ![red] -23.83% | ![red] -29.52% |
| C (auto-increment PK, ext UUID)   | ![org] -14.79% | ![grn]  +0.49% | ![org]  -9.17% | ![red] -15.61% |

#### `customer_new_order` TPS / MySQL / Medium DB size

![New customer orders - MySQL - medium DB](uuid-vs-integer/images/customer_new_order-mysql-medium.png "MySQL - Medium DB - New customer order transactions per second")

| Schema design                     |       1      |      2      |      4      |      8      |
| --------------------------------- | ------------:| -----------:| -----------:| -----------:|
| A (auto-increment PKs no UUID)    |       138.74 |      367.78 |      718.83 |     1417.25 |
| B (UUID PKs only)                 |       114.87 |      260.26 |      565.07 |     1027.15 |
| C (auto-increment PK, ext UUID)   |       121.28 |      333.61 |      696.10 |     1258.69 |

The following table shows the differences in TPS compared to schema design "A".

| Schema design                     |   1            |   2            |    4           |      8         |
| --------------------------------- | --------------:| --------------:| --------------:| --------------:|
| B (UUID PKs only)                 | ![red] -17.20% | ![red] -29.23% | ![red] -21.39% | ![red] -27.52% |
| C (auto-increment PK, ext UUID)   | ![org] -12.58% | ![org]  -9.29% | ![grn]  -3.16% | ![org] -11.18% |

#### `customer_new_order` TPS / MySQL / Large DB size

![New customer orders - MySQL - large DB](uuid-vs-integer/images/customer_new_order-mysql-large.png "MySQL - Large DB - New customer order transactions per second")

| Schema design                     |       1      |      2      |      4      |      8      |
| --------------------------------- | ------------:| -----------:| -----------:| -----------:|
| A (auto-increment PKs no UUID)    |        46.39 |      112.80 |      333.28 |      586.64 |
| B (UUID PKs only)                 |        66.06 |      162.16 |      160.23 |      170.11 |
| C (auto-increment PK, ext UUID)   |        49.84 |      116.42 |      326.95 |      746.46 |

The following table shows the differences in TPS compared to schema design "A".

| Schema design                     |   1            |   2            |    4           |      8         |
| --------------------------------- | --------------:| --------------:| --------------:| --------------:|
| B (UUID PKs only)                 | ![grn] +42.40% | ![grn] +43.75% | ![red] -50.92% | ![red] -71.00% |
| C (auto-increment PK, ext UUID)   | ![grn]  +7.43% | ![grn]  +3.20% | ![grn]  -1.89% | ![grn] +27.24% |

#### `customer_new_order` summary for MySQL

So, what are some things we can take away from the above results for our mixed
read/write `customer_new_order` scenario? Well, there are a few.

For MySQL, schema design "B" (UUID primary keys) consistently performed
significantly worse than both schema design "A" and schema design "C". We can
theorize that because UUIDs are not created in sequential order and because
InnoDB lays out its tables in a clustered index organization (meaning, the data
pages are sorted by primary key), InnoDB is doing more random I/O for schema
design "B" since new primary keys are not guaranteed to be at the tail of the
latest data page.

**NOTE**: InnoDB doesn't actually store all the table record data sorted by the
primary key value. Instead, inside each InnoDB data page there is a little
dictionary of primary key values along with a pointer/offset to where the
remainder of that record's data can be found within that data page. That said,
this dictionary still needs to be sorted by primary key value, and since new
primary keys are not guaranteed to go at the end of this dictionary, that means
more random I/O and insertion sorts than schema designs "B" or "C".

For MySQL, we see that the performance of schema design "C" is worse than
schema design "A" for the smaller initial database sizes (though never anywhere
as bad as schema design "B"). However, the larger the initial database size,
the better schema design "C" performs. At the "large" initial database size,
schema design "C" is either comparable to or outperforming the performance of
schema design "A".

Recall that for the "large" initial database size, the `order_details` fact
table was bigger than the entire InnoDB buffer pool (128M). This means that in
order to satisfy the `customer_new_order` scenario, InnoDB needs to read some
data from the buffer pool and write new records into the buffer pool. Due to
the random I/O needed by the UUID primary keys, there is a higher likelihood
that InnoDB will need to read data pages from disk instead of memory. For
schema designs "A" and "C", there is virtually zero chance that InnoDB will
need to read a data page from disk because previous records will have been
written into a data page that is in the buffer pool already (since we know that
the previous record will most likely be in the data page we are writing the
current record to). We can see the effects of this in the abysmal performance
of  schema design "B" at higher concurrency levels for the "large" initial
database size. Regardless of the number of concurrent threads, we're unable to
exceed 170.11 transactions per second, which at 8 concurrent threads is a **71%
decrease** in performance from schema design "A".

#### `customer_new_order` TPS / PostgreSQL / Small DB size

![New customer orders - PostgreSQL - small DB](uuid-vs-integer/images/customer_new_order-pgsql-small.png "PostgreSQL - Small DB - New customer order transactions per second")

| Schema design                     |       1      |      2      |      4      |      8      |
| --------------------------------- | ------------:| -----------:| -----------:| -----------:|
| A (auto-increment PKs no UUID)    |        88.19 |      181.25 |      401.69 |      759.64 |
| B (UUID PKs only)                 |        85.04 |      184.81 |      427.15 |      723.35 |
| C (auto-increment PK, ext UUID)   |        94.53 |      185.23 |      409.03 |      700.94 |

The following table shows the differences in TPS compared to schema design "A".

| Schema design                     |   1            |   2            |    4           |      8         |
| --------------------------------- | --------------:| --------------:| --------------:| --------------:|
| B (UUID PKs only)                 | ![grn]  -3.57% | ![grn]  +1.96% | ![grn]  +6.33% | ![grn]  +4.77% |
| C (auto-increment PK, ext UUID)   | ![grn]  +7.18% | ![grn]  +2.19% | ![grn]  -1.82% | ![org]  -7.72% |

#### `customer_new_order` TPS / PostgreSQL / Medium DB size

![New customer orders - PostgreSQL - medium DB](uuid-vs-integer/images/customer_new_order-pgsql-medium.png "PostgreSQL - Medium DB - New customer order transactions per second")

| Schema design                     |       1      |      2      |      4      |      8      |
| --------------------------------- | ------------:| -----------:| -----------:| -----------:|
| A (auto-increment PKs no UUID)    |        85.26 |      167.98 |      370.44 |      717.92 |
| B (UUID PKs only)                 |        80.66 |      167.91 |      371.69 |      689.94 |
| C (auto-increment PK, ext UUID)   |        82.44 |      170.41 |      340.48 |      694.29 |

The following table shows the differences in TPS compared to schema design "A".

| Schema design                     |   1            |   2            |    4           |      8         |
| --------------------------------- | --------------:| --------------:| --------------:| --------------:|
| B (UUID PKs only)                 | ![org]  -5.39% | ![grn]  -0.04% | ![grn]  +0.33% | ![grn]  -3.89% |
| C (auto-increment PK, ext UUID)   | ![grn]  -3.30% | ![grn]  +1.44% | ![org]  -8.08% | ![grn]  -3.29% |

#### `customer_new_order` TPS / PostgreSQL / Large DB size

![New customer orders - PostgreSQL - large DB](uuid-vs-integer/images/customer_new_order-pgsql-large.png "PostgreSQL - Large DB - New customer order transactions per second")

| Schema design                     |       1      |      2      |      4      |      8      |
| --------------------------------- | ------------:| -----------:| -----------:| -----------:|
| A (auto-increment PKs no UUID)    |        66.07 |      126.03 |      240.17 |      480.51 |
| B (UUID PKs only)                 |        65.23 |      124.42 |      239.46 |      457.44 |
| C (auto-increment PK, ext UUID)   |        64.40 |      124.48 |      230.29 |      468.28 |

The following table shows the differences in TPS compared to schema design "A".

| Schema design                     |   1            |   2            |    4           |      8         |
| --------------------------------- | --------------:| --------------:| --------------:| --------------:|
| B (UUID PKs only)                 | ![grn]  -1.27% | ![grn]  -1.27% | ![grn]  -0.29% | ![grn]  -4.80% |
| C (auto-increment PK, ext UUID)   | ![grn]  -2.52% | ![grn]  -1.22% | ![grn]  -4.11% | ![grn]  -2.54% |

#### `customer_new_order` summary for PostgreSQL

For PostgreSQL, we see **very little difference** between the three schema
designs for the `customer_new_order` scenario on each of the initial database
sizes. Transactions per second nicely double for each doubling of concurrent
threads, regardless of the schema design.

I was a little surprised by this result for PostgreSQL. Although PostgreSQL has
a native UUID column type, the UUIDs generated by the scenario are certainly
not ordered. And I know that PostgreSQL uses a clustered index organization for
its table layout, so I would have expected to see a performance degradation
resulting from that clustered index being searched and insertion-sorted
repeatedly for those new random UUID values. My suspicion is that even with the
"large" initial database size, that PostgreSQL's table buffers were still
entirely in memory and therefore the effect of the random I/O read and write
patterns were less pronounced. I may run the scenario with an initial database
size that I know exceeds PostgreSQL's default buffer sizes and see if the
effect can be reproduced in PostgreSQL.

### Order counts by status results

Here are the number of transactions per second that were possible (for N
concurrent threads) for the `order_counts_by_status` scenario. These
transactions were an identical `SELECT` statement that returned the count of
orders per distinct status.

This `SELECT` statement involved an aggregate query against a single table
using a secondary index on the column involved in the grouping expression
(`orders.status`).

#### `order_counts_by_status` QPS / MySQL / Small DB size

![Order counts by status - MySQL - small DB](uuid-vs-integer/images/order_counts_by_status-mysql-small.png "MySQL - Small DB - Order counts by status queries per second")

| Schema design                     |       1      |      2      |      4      |      8      |
| --------------------------------- | ------------:| -----------:| -----------:| -----------:|
| A (auto-increment PKs no UUID)    |      1615.89 |     3075.88 |     7198.23 |    11203.62 |
| B (UUID PKs only)                 |      1549.78 |     2887.22 |     6702.80 |    10635.49 |
| C (auto-increment PK, ext UUID)   |      1544.83 |     2873.24 |     6545.08 |    10598.03 |

The following table shows the differences in TPS compared to schema design "A".

| Schema design                     |   1            |   2            |    4           |      8         |
| --------------------------------- | --------------:| --------------:| --------------:| --------------:|
| B (UUID PKs only)                 | ![grn]  -4.09% | ![org]  -6.13% | ![org]  -6.88% | ![org]  -5.07% |
| C (auto-increment PK, ext UUID)   | ![grn]  -4.39% | ![org]  -6.58% | ![org]  -9.07% | ![org]  -5.40% |

#### `order_counts_by_status` QPS / MySQL / Medium DB size

![Order counts by status - MySQL - medium DB](uuid-vs-integer/images/order_counts_by_status-mysql-medium.png "MySQL - Medium DB - Order counts by status queries per second")

| Schema design                     |       1      |      2      |      4      |      8      |
| --------------------------------- | ------------:| -----------:| -----------:| -----------:|
| A (auto-increment PKs no UUID)    |       584.69 |     1119.66 |     2287.99 |     3643.57 |
| B (UUID PKs only)                 |       556.03 |     1062.13 |     2179.67 |     3388.88 |
| C (auto-increment PK, ext UUID)   |       556.27 |     1072.93 |     2114.73 |     3356.61 |

The following table shows the differences in TPS compared to schema design "A".

| Schema design                     |   1            |   2            |    4           |      8         |
| --------------------------------- | --------------:| --------------:| --------------:| --------------:|
| B (UUID PKs only)                 | ![grn]  -4.90% | ![org]  -5.13% | ![grn]  -4.73% | ![org]  -6.99% |
| C (auto-increment PK, ext UUID)   | ![grn]  -4.86% | ![grn]  -4.17% | ![org]  -7.57% | ![org]  -7.87% |

#### `order_counts_by_status` QPS / MySQL / Large DB size

![Order counts by status - MySQL - large DB](uuid-vs-integer/images/order_counts_by_status-mysql-large.png "MySQL - Large DB - Order counts by status queries per second")

| Schema design                     |       1      |      2      |      4      |      8      |
| --------------------------------- | ------------:| -----------:| -----------:| -----------:|
| A (auto-increment PKs no UUID)    |        46.92 |       93.21 |      174.94 |      270.34 |
| B (UUID PKs only)                 |        41.86 |       82.61 |      157.42 |      248.07 |
| C (auto-increment PK, ext UUID)   |        43.69 |       87.07 |      167.99 |      244.56 |

The following table shows the differences in TPS compared to schema design "A".

| Schema design                     |   1            |   2            |    4           |      8         |
| --------------------------------- | --------------:| --------------:| --------------:| --------------:|
| B (UUID PKs only)                 | ![org] -10.84% | ![org] -11.37% | ![org] -10.01% | ![org]  -8.23% |
| C (auto-increment PK, ext UUID)   | ![org]  -6.88% | ![org]  -6.58% | ![grn]  -3.97% | ![org]  -9.53% |

#### `order_counts_by_status` summary for MySQL

Recall that this scenario is intended to spot the impact of primary key column
type choice for queries that do **NOT** involve the primary key. The query
simply does an scan of the index on `orders.status`, tallying counts of each
distinct value in the index.

However, also remember that InnoDB's secondary index records **always contain
the primary key value in addition to the values of the fields involved in the
secondary index**.

What this means is that for schema design "B", each record in the index on
`orders.status` contains the 36-byte UUID primary key value.  For schema design
"C", each index record contains the 4-byte integer primary key value. The
`orders.status` field is a `VARCHAR(20)` column type that has an average length
of around 7 bytes. Extrapolating from these numbers, we can see that for schema
design "B", the average index record length will be **42 bytes** and for schema
design "C" it will be **11 bytes**. That's approximately **4X the number of index
records** that can fit into a single page of memory so I would have expected to
see a significant decrease in performance for schema design "B" compared to
schema design "A". And I expected to see nearly identical performance to "A"
from schema design "C".

This is **NOT**, however, what we see in the results.

For the "small" and "medium" initial database sizes, we see a small (less than
10%) decrease in queries per second for both schema design "B" and "C". For the
"large" initial database size, we see a pretty consistent 10% or slightly more
decrease in QPS for schema design "B" and a likewise fairly consistent smaller
decrease in performance for schema design "C".

The negative effect of the larger index record size for schema design "B"
certainly is more evident on the larger initial database size. I would surmise
that as the database size grows, that negative effect will also grow due to the
chance that index pages will not be in memory and will thus need to be spooled
from disk in order to be read for the query. The larger index record size means
more index pages are needed, which means greater chance of being pulled from
disk.

In summary, the only really surprising result for this scenario (for MySQL) was
that there was any negative impact for schema design "C". From what I know
about InnoDB internals, I would have expected nearly identical performance of
this particular query for schema designs "A" and "C".

#### `order_counts_by_status` QPS / PostgreSQL / Small DB size

![Order counts by status - PostgreSQL - small DB](uuid-vs-integer/images/order_counts_by_status-pgsql-small.png "PostgreSQL - Small DB - Order counts by status queries per second")

| Schema design                     |       1      |      2      |      4      |      8      |
| --------------------------------- | ------------:| -----------:| -----------:| -----------:|
| A (auto-increment PKs no UUID)    |      1254.54 |     2996.22 |     5668.34 |    10450.70 |
| B (UUID PKs only)                 |      1439.05 |     2849.36 |     5468.08 |    10473.11 |
| C (auto-increment PK, ext UUID)   |      1455.38 |     2875.40 |     5527.62 |    10248.12 |

The following table shows the differences in TPS compared to schema design "A".

| Schema design                     |   1            |   2            |    4           |      8         |
| --------------------------------- | --------------:| --------------:| --------------:| --------------:|
| B (UUID PKs only)                 | ![grn] +14.70% | ![grn]  -4.90% | ![grn]  -3.53% | ![grn]  +0.21% |
| C (auto-increment PK, ext UUID)   | ![grn] +16.00% | ![grn]  -4.03% | ![grn]  -2.48% | ![grn]  -1.93% |

#### `order_counts_by_status` QPS / PostgreSQL / Medium DB size

![Order counts by status - PostgreSQL - medium DB](uuid-vs-integer/images/order_counts_by_status-pgsql-medium.png "PostgreSQL - Medium DB - Order counts by status queries per second")

| Schema design                     |       1      |      2      |      4      |      8      |
| --------------------------------- | ------------:| -----------:| -----------:| -----------:|
| A (auto-increment PKs no UUID)    |       466.88 |      946.12 |     2043.78 |     3406.51 |
| B (UUID PKs only)                 |       457.35 |      872.31 |     1953.07 |     3412.37 |
| C (auto-increment PK, ext UUID)   |       453.27 |      899.54 |     2036.88 |     3284.91 |

The following table shows the differences in TPS compared to schema design "A".

| Schema design                     |   1            |   2            |    4           |      8         |
| --------------------------------- | --------------:| --------------:| --------------:| --------------:|
| B (UUID PKs only)                 | ![grn]  -2.04% | ![org]  -7.80% | ![grn]  -4.43% | ![grn]  +0.17% |
| C (auto-increment PK, ext UUID)   | ![grn]  -2.91% | ![grn]  -4.92% | ![grn]  -0.33% | ![grn]  -3.56% |

#### `order_counts_by_status` QPS / PostgreSQL / Large DB size

![Order counts by status - PostgreSQL - large DB](uuid-vs-integer/images/order_counts_by_status-pgsql-large.png "PostgreSQL - Large DB - Order counts by status queries per second")

| Schema design                     |       1      |      2      |      4      |      8      |
| --------------------------------- | ------------:| -----------:| -----------:| -----------:|
| A (auto-increment PKs no UUID)    |        43.38 |       84.24 |      158.37 |      249.28 |
| B (UUID PKs only)                 |        43.37 |       81.41 |      165.51 |      246.39 |
| C (auto-increment PK, ext UUID)   |        42.13 |       83.65 |      162.79 |      240.66 |

The following table shows the differences in TPS compared to schema design "A".

| Schema design                     |   1            |   2            |    4           |      8         |
| --------------------------------- | --------------:| --------------:| --------------:| --------------:|
| B (UUID PKs only)                 | ![grn]  -0.02% | ![grn]  -3.35% | ![grn]  +4.50% | ![grn]  -1.15% |
| C (auto-increment PK, ext UUID)   | ![grn]  -2.88% | ![grn]  -0.70% | ![grn]  +2.79% | ![grn]  -3.45% |

#### `order_counts_by_status` summary for PostgreSQL

For PostgreSQL, there was virtually no difference in queries per second for any
initial database size or schema design. There was only a single result (for the
"medium" initial database size and 2 concurrent threads) where the performance
delta was greater than 4.99%. I view this as a slight anomaly based on the
remainder of the consistent results. Perhaps some vacuuming or auto-cleanup
activity occurred during that particular run.

### Lookup customer orders results

Here are the number of transactions per second that were possible (for N
concurrent threads) for the `lookup_orders_by_customer` scenario. These
transactions were a single `SELECT` statement that returned the latest (by
created_on date) orders for a customer, with the number of items in the order
and the amount of the order. This `SELECT` statement involved a lookup via
customer external identifier (either auto-incrementing integer key or UUID)
along with an aggregate operation across a set of records in the
`order_details` table via a multi-table `JOIN` operation.

#### `lookup_orders_by_customer` QPS / MySQL / Small DB size

![Lookup orders by customer - MySQL - small DB](uuid-vs-integer/images/lookup_orders_by_customer-mysql-small.png "MySQL - Small DB - Lookup orders by customer queries per second")

| Schema design                     |       1      |      2      |      4      |      8      |
| --------------------------------- | ------------:| -----------:| -----------:| -----------:|
| A (auto-increment PKs no UUID)    |      5930.91 |    11430.37 |    23525.73 |    40916.91 |
| B (UUID PKs only)                 |      5266.74 |    10396.43 |    22760.17 |    39067.47 |
| C (auto-increment PK, ext UUID)   |      4901.82 |    10004.68 |    20750.32 |    36366.61 |

The following table shows the differences in TPS compared to schema design "A".

| Schema design                     |   1            |   2            |    4           |      8         |
| --------------------------------- | --------------:| --------------:| --------------:| --------------:|
| B (UUID PKs only)                 | ![org] -11.19% | ![org]  -9.04% | ![grn]  -3.25% | ![grn]  -4.51% |
| C (auto-increment PK, ext UUID)   | ![red] -17.35% | ![org] -12.47% | ![org] -11.79% | ![org] -11.12% |

#### `lookup_orders_by_customer` QPS / MySQL / Medium DB size

![Lookup orders by customer - MySQL - medium DB](uuid-vs-integer/images/lookup_orders_by_customer-mysql-medium.png "MySQL - Medium DB - Lookup orders by customer queries per second")

| Schema design                     |       1      |      2      |      4      |      8      |
| --------------------------------- | ------------:| -----------:| -----------:| -----------:|
| A (auto-increment PKs no UUID)    |      5097.35 |     9967.02 |    21322.79 |    37746.48 |
| B (UUID PKs only)                 |      4706.99 |     9606.48 |    20007.97 |    35569.34 |
| C (auto-increment PK, ext UUID)   |      4182.20 |     8869.60 |    18231.92 |    33571.22 |

The following table shows the differences in TPS compared to schema design "A".

| Schema design                     |   1            |   2            |    4           |      8         |
| --------------------------------- | --------------:| --------------:| --------------:| --------------:|
| B (UUID PKs only)                 | ![org]  -7.65% | ![grn]  -3.61% | ![org]  -6.16% | ![org]  -5.76% |
| C (auto-increment PK, ext UUID)   | ![red] -17.95% | ![org] -11.01% | ![org] -14.49% | ![org] -11.06% |

#### `lookup_orders_by_customer` QPS / MySQL / Large DB size

![Lookup orders by customer - MySQL - large DB](uuid-vs-integer/images/lookup_orders_by_customer-mysql-large.png "MySQL - Large DB - Lookup orders by customer queries per second")

| Schema design                     |       1      |      2      |      4      |      8      |
| --------------------------------- | ------------:| -----------:| -----------:| -----------:|
| A (auto-increment PKs no UUID)    |      2404.02 |     4785.85 |    10014.97 |    18708.46 |
| B (UUID PKs only)                 |      1848.24 |     3812.25 |     6326.06 |     8994.89 |
| C (auto-increment PK, ext UUID)   |      2380.97 |     4582.94 |     9561.05 |    17585.76 |

The following table shows the differences in TPS compared to schema design "A".

| Schema design                     |   1            |   2            |    4           |      8         |
| --------------------------------- | --------------:| --------------:| --------------:| --------------:|
| B (UUID PKs only)                 | ![red] -23.11% | ![red] -20.34% | ![red] -36.83% | ![red] -51.92% |
| C (auto-increment PK, ext UUID)   | ![grn]  -0.95% | ![grn]  -4.23% | ![grn]  -4.53% | ![org]  -6.00% |

#### `lookup_orders_by_customer` summary for MySQL

This scenario is all about showing the impact of the primary key column type on
the performance of `JOIN` operations.

`JOIN` operations (specifically the `eq_join` operation that will satisfy an
`ON` condition containing an equality comparator) will read index records from
both sides of the `JOIN`, comparing the values of the fields in the `ON` clause
to determine if the table record meets the equality condition.

Clearly, the greater the number of index records that can be placed in a single
page in memory for this comparison work, the faster the work will be completed
and thus the faster the `JOIN` operation will be.

The `SELECT` statement involved in this scenario required one additional `JOIN`
for schema design "C" -- in order to do the lookup of internal customer integer
ID from the external customer UUID. Therefore, I expected to see a small
performance decrease for schema design "C" compared to schema design "A" across
all initial database sizes.

For schema design "B", I expected to see similar performance to schema design
"A" for database sizes that could fit entirely in the InnoDB buffer pool and a
small to medium decrease in performance once the database could no longer fit
in memory.

The results we see for this scenario *mostly* matched my expectations, with a
couple surprises.

First, I was surprised to see schema design "C" perform poorly in the smaller
initial database sizes compared to schema design "A". A single additional
`eq_join` operation to match the customer's internal integer identifier to the
supplied external customer UUID resulted in a a greater than **10% decrease**
in overall performance for both "small" and "medium" initial database sizes. I
had expected to see this number more in the 5% or less range.

Secondly, I was surprised by the drop-off in performance of schema design "B"
at the "large" initial database size. I expected some amount of negative
impact, but clearly once the database no longer fits in resident memory, the
impact of primary key column type really starts to show up. At 8 concurrent
threads, schema design "B" had a **greater than 50% decrease** in performance
compared to schema design "A".

By contrast, once the database no longer fit in resident memory, schema design
"C" started to shine. We no longer see the 10%+ decrease in performance
compared to schema design "A" and instead modest decreases in performance of 5%
or less.

#### `lookup_orders_by_customer` QPS / PostgreSQL / Small DB size

![Lookup orders by customer - PostgreSQL - small DB](uuid-vs-integer/images/lookup_orders_by_customer-pgsql-small.png "PostgreSQL - Small DB - Lookup orders by customer queries per second")

| Schema design                     |       1      |      2      |      4      |      8      |
| --------------------------------- | ------------:| -----------:| -----------:| -----------:|
| A (auto-increment PKs no UUID)    |      5535.84 |    10517.41 |    23550.26 |    40626.90 |
| B (UUID PKs only)                 |      5398.67 |    10588.56 |    22427.03 |    40596.57 |
| C (auto-increment PK, ext UUID)   |      4992.97 |    10000.48 |    20384.42 |    38204.45 |

The following table shows the differences in TPS compared to schema design "A".

| Schema design                     |   1            |   2            |    4           |      8         |
| --------------------------------- | --------------:| --------------:| --------------:| --------------:|
| B (UUID PKs only)                 | ![grn]  -2.47% | ![grn]  +0.67% | ![grn]  -4.76% | ![grn]  -0.07% |
| C (auto-increment PK, ext UUID)   | ![org]  -9.80% | ![grn]  -4.91% | ![org] -13.44% | ![org]  -5.96% |

#### `lookup_orders_by_customer` QPS / PostgreSQL / Medium DB size

![Lookup orders by customer - PostgreSQL - medium DB](uuid-vs-integer/images/lookup_orders_by_customer-pgsql-medium.png "PostgreSQL - Medium DB - Lookup orders by customer queries per second")

| Schema design                     |       1      |      2      |      4      |      8      |
| --------------------------------- | ------------:| -----------:| -----------:| -----------:|
| A (auto-increment PKs no UUID)    |      4950.84 |     9455.83 |    21038.52 |    36402.19 |
| B (UUID PKs only)                 |      4877.40 |     9420.81 |    20228.23 |    36158.88 |
| C (auto-increment PK, ext UUID)   |      4769.36 |     9672.92 |    18087.29 |    34486.62 |

The following table shows the differences in TPS compared to schema design "A".

| Schema design                     |   1            |   2            |    4           |      8         |
| --------------------------------- | --------------:| --------------:| --------------:| --------------:|
| B (UUID PKs only)                 | ![grn]  -1.48% | ![grn]  -0.37% | ![grn]  -3.85% | ![grn]  -0.66% |
| C (auto-increment PK, ext UUID)   | ![grn]  -3.66% | ![grn]  +2.29% | ![org] -14.02% | ![org]  -5.26% |

#### `lookup_orders_by_customer` QPS / PostgreSQL / Large DB size

![Lookup orders by customer - PostgreSQL - large DB](uuid-vs-integer/images/lookup_orders_by_customer-pgsql-large.png "PostgreSQL - Large DB - Lookup orders by customer queries per second")

| Schema design                     |       1      |      2      |      4      |      8      |
| --------------------------------- | ------------:| -----------:| -----------:| -----------:|
| A (auto-increment PKs no UUID)    |      1920.31 |     4170.13 |     7712.94 |    15930.49 |
| B (UUID PKs only)                 |      1901.57 |     4093.66 |     7169.58 |    14934.87 |
| C (auto-increment PK, ext UUID)   |      1993.65 |     3768.92 |     7484.78 |    14854.96 |

The following table shows the differences in TPS compared to schema design "A".

| Schema design                     |   1            |   2            |    4           |      8         |
| --------------------------------- | --------------:| --------------:| --------------:| --------------:|
| B (UUID PKs only)                 | ![grn]  -0.97% | ![grn]  -1.83% | ![org]  -7.04% | ![org]  -6.24% |
| C (auto-increment PK, ext UUID)   | ![grn]  +3.81% | ![org]  -9.62% | ![grn]  -2.95% | ![org]  -6.75% |

#### `lookup_orders_by_customer` summary for PostgreSQL

For PostgreSQL, as was the case for the `order_counts_by_status` scenario, we
saw less of a performance degradation between schema design "A" for both schema
design "B" and "C".

For the "small" and "medium" initial database sizes, we see a greater decrease
in performance for schema design "C" at higher concurrency levels. This can be
explained by the extra `JOIN` to the customers table that is necessary to
satisfy the external to internal identifier lookup.

For the "large" initial database size, results were inconclusive. I can detect
no discernable difference between schema design "B" and schema design "C" when
compared to the performance of schema design "A". I may re-run this particular
benchmark for larger-still initial database sizes and see if a pattern emerges.

### Lookup most popular items results

Here are the number of transactions per second that were possible (for N
concurrent threads) for the `lookup_most_popular_items` scenario. These
transactions were a single `SELECT` statement that returned the most
popular-selling items in the store and the supplier that fulfilled that product
the most. It involves a full table scan of all records in the `order_details`
table and `JOIN` operations to multiple tables including the `products` and
`suppliers` tables.

#### `popular_items` QPS / MySQL / Small DB size

![Popular items - MySQL - small DB](uuid-vs-integer/images/popular_items-mysql-small.png "MySQL - Small DB - Popular items queries per second")

| Schema design                     |       1      |      2      |      4      |      8      |
| --------------------------------- | ------------:| -----------:| -----------:| -----------:|
| A (auto-increment PKs no UUID)    |        59.81 |      113.44 |      196.46 |      312.38 |
| B (UUID PKs only)                 |        43.34 |       83.35 |      132.46 |      230.66 |
| C (auto-increment PK, ext UUID)   |        64.11 |      119.79 |      187.27 |      325.28 |

The following table shows the differences in TPS compared to schema design "A".

| Schema design                     |   1            |   2            |    4           |      8         |
| --------------------------------- | --------------:| --------------:| --------------:| --------------:|
| B (UUID PKs only)                 | ![red] -27.53% | ![red] -26.52% | ![red] -32.57% | ![red] -26.16% |
| C (auto-increment PK, ext UUID)   | ![grn]  +7.18% | ![grn]  +5.59% | ![grn]  -4.67% | ![grn]  +4.12% |

#### `popular_items` QPS / MySQL / Medium DB size

![Popular items - MySQL - medium DB](uuid-vs-integer/images/popular_items-mysql-medium.png "MySQL - Medium DB - Popular items queries per second")

| Schema design                     |       1      |      2      |      4      |      8      |
| --------------------------------- | ------------:| -----------:| -----------:| -----------:|
| A (auto-increment PKs no UUID)    |        12.49 |       23.14 |       38.50 |       64.81 |
| B (UUID PKs only)                 |         9.43 |       17.69 |       33.69 |       51.24 |
| C (auto-increment PK, ext UUID)   |        12.06 |       22.52 |       41.17 |       63.02 |

The following table shows the differences in TPS compared to schema design "A".

| Schema design                     |   1            |   2            |    4           |      8         |
| --------------------------------- | --------------:| --------------:| --------------:| --------------:|
| B (UUID PKs only)                 | ![red] -24.49% | ![red] -23.55% | ![org] -12.49% | ![red] -20.93% |
| C (auto-increment PK, ext UUID)   | ![grn]  -3.44% | ![grn]  -2.69% | ![grn]  +6.93% | ![grn]  -2.76% |

#### `popular_items` QPS / MySQL / Large DB size

![Popular items - MySQL - large DB](uuid-vs-integer/images/popular_items-mysql-large.png "MySQL - Large DB - Popular items queries per second")

| Schema design                     |       1      |      2      |      4      |      8      |
| --------------------------------- | ------------:| -----------:| -----------:| -----------:|
| A (auto-increment PKs no UUID)    |         0.16 |        0.29 |        0.50 |        0.68 |
| B (UUID PKs only)                 |         0.05 |        0.09 |        0.11 |        0.11 |
| C (auto-increment PK, ext UUID)   |         0.16 |        0.30 |        0.52 |        0.73 |

The following table shows the differences in TPS compared to schema design "A".

| Schema design                     |   1            |   2            |    4           |      8         |
| --------------------------------- | --------------:| --------------:| --------------:| --------------:|
| B (UUID PKs only)                 | ![red] -68.75% | ![red] -68.96% | ![red] -78.00% | ![red] -83.82% |
| C (auto-increment PK, ext UUID)   | ![grn]  +0.00% | ![grn]  +3.44% | ![grn]  +4.00% | ![grn]  +7.35% |

#### `popular_items` summary for MySQL

This scenario shows the impact of the primary key column type on the
performance of a complex aggregate query with multiple joined tables.

I expected schema design "B" to exhibit poorer performance than schema design
"A" due to the increased index record size. Since the `SELECT` query touches
each row in our fact table (`order_details`) and performs a join to both the
`products` and `suppliers` tables to get product and supplier names, lots of
I/O is done with each execution of the `SELECT` query. Because larger index
records means more I/O to perform to complete the same calculations, I expected
schema design "B" to suffer compared to schema design "A".

And suffer it did.

Even on the "small" initial database sizes, schema design "B" performed around
**28% worse** than schema design "A". The "medium" initial database size was
around **20% worse** and the "large" initial database size was more than a
whopping **70% worse** than schema design "A".

We see that the 4X increase in secondary index record size results in terrible
performance when so many fewer index pages can be spooled into memory compared
to the schema designs with smaller primary key column types.

Interestingly, we see that schema design "C" actually **performs better** than
schema design "A" for this scenario. I'm puzzled why this is the case, but
strangely we see a similar (though less exaggerated) effect in the PostgreSQL
results for this scenario, so I don't believe it to be an anomaly.

#### `popular_items` QPS / PostgreSQL / Small DB size

![Popular items - PostgreSQL - small DB](uuid-vs-integer/images/popular_items-pgsql-small.png "PostgreSQL - Small DB - Popular items queries per second")

| Schema design                     |       1      |      2      |      4      |      8      |
| --------------------------------- | ------------:| -----------:| -----------:| -----------:|
| A (auto-increment PKs no UUID)    |        87.55 |      173.34 |      337.37 |      512.03 |
| B (UUID PKs only)                 |        78.98 |      156.74 |      295.90 |      446.05 |
| C (auto-increment PK, ext UUID)   |        87.94 |      173.78 |      317.02 |      484.17 |

The following table shows the differences in TPS compared to schema design "A".

| Schema design                     |   1            |   2            |    4           |      8         |
| --------------------------------- | --------------:| --------------:| --------------:| --------------:|
| B (UUID PKs only)                 | ![org]  -9.78% | ![red]  -9.57% | ![org] -12.29% | ![org] -12.88% |
| C (auto-increment PK, ext UUID)   | ![grn]  +0.44% | ![grn]  +0.25% | ![org]  -6.03% | ![org]  -5.44% |

#### `popular_items` QPS / PostgreSQL / Medium DB size

![Popular items - PostgreSQL - medium DB](uuid-vs-integer/images/popular_items-pgsql-medium.png "PostgreSQL - Medium DB - Popular items queries per second")

| Schema design                     |       1      |      2      |      4      |      8      |
| --------------------------------- | ------------:| -----------:| -----------:| -----------:|
| A (auto-increment PKs no UUID)    |        19.12 |       37.78 |       69.72 |      106.62 |
| B (UUID PKs only)                 |        13.51 |       26.21 |       48.32 |       71.11 |
| C (auto-increment PK, ext UUID)   |        18.92 |       36.71 |       68.75 |      104.27 |

The following table shows the differences in TPS compared to schema design "A".

| Schema design                     |   1            |   2            |    4           |      8         |
| --------------------------------- | --------------:| --------------:| --------------:| --------------:|
| B (UUID PKs only)                 | ![red] -29.34% | ![red] -30.62% | ![red] -30.69% | ![red] -33.30% |
| C (auto-increment PK, ext UUID)   | ![grn]  -1.04% | ![grn]  -2.83% | ![grn]  -1.39% | ![grn]  -2.20% |

#### `popular_items` QPS / PostgreSQL / Large DB size

![Popular items - PostgreSQL - large DB](uuid-vs-integer/images/popular_items-pgsql-large.png "PostgreSQL - Large DB - Popular items queries per second")

| Schema design                     |       1      |      2      |      4      |      8      |
| --------------------------------- | ------------:| -----------:| -----------:| -----------:|
| A (auto-increment PKs no UUID)    |         0.38 |        0.68 |        1.35 |        1.95 |
| B (UUID PKs only)                 |         0.30 |        0.57 |        1.03 |        1.50 |
| C (auto-increment PK, ext UUID)   |         0.38 |        0.72 |        1.34 |        1.97 |

The following table shows the differences in TPS compared to schema design "A".

| Schema design                     |   1            |   2            |    4           |      8         |
| --------------------------------- | --------------:| --------------:| --------------:| --------------:|
| B (UUID PKs only)                 | ![red] -21.05% | ![red] -16.17% | ![red] -23.70% | ![red] -23.07% |
| C (auto-increment PK, ext UUID)   | ![grn]  +0.00% | ![grn]  +5.88% | ![grn]  -0.74% | ![grn]  +1.02% |

#### `popular_items` summary for PostgreSQL

The impact of primary key column type was most evident for the `popular_items`
scenario for PostgreSQL. As was the case for MySQL, we see a **consistent and
significant performance degradation** for schema design "B" at all initial
database sizes and concurrency levels.

While the "small" initial database size saw schema design "B" perform around
**10% slower** than schema design "A", the larger initial database sizes saw
between **20 and 32% slowdowns at all concurrency levels**.

For schema design "C", we see a similar pattern emerge as we saw with the MySQL
results. Schema design "C" performs comparable to schema design "A" but for the
"large" initial database size, we see schema design "C" comparable to or
outperforming schema design "A" pretty consistently at all concurrency levels.

## Conclusions

So what conclusions and recommendations can we draw from these benchmark
results?

For starters, I think we can definitively say that **the choice of
sequentially-generated integers versus randomly-generated has a _real and
demonstrable_ impact on the performance of both read and write workloads for
both MySQL and PostgreSQL**.

While **the impact on performance was smaller for PostgreSQL**, for certain
workloads involving writes and complex aggregate queries, the impact is
definitely apparent. This smaller impact can likely be attributed to
PostgreSQL's native UUID type, which stores UUID values more compactly than the
`CHAR(36)` column type used for MySQL in these benchmarks.

For **MySQL**, the impact of primary key column type is **greatly exaggerated when
the size of the database exceeds the InnoDB buffer pool**.

For all scenarios with MySQL, the **"large" initial database size** -- which
contained a fact table larger than the entire InnoDB buffer pool -- showed that
**schema design "B" performed poorly compared to schema design "A"**. At the
"large" initial database size, **schema design "B" performed poorly compared to
schema design "C"** even after accounting for the additional reads and/or joins
required by schema design "C".

Due to the scale-out / sharding problems inherent with using auto-incrementing
integers as **external identifiers**, my recommendation is to **use UUIDs for
your application's external identifiers**.

If you are going to use UUIDs as your application's external identifiers, then
your choice is between schema design "B" and schema design "C". I think based
on the results contained in this benchmark, I would recommend going with schema
design "C" to avoid some of the performance problems for **some workloads** at
higher concurrency and database sizes.

Your comments, concerns and questions are most welcome. Either tweet me
[@jaypipes](https://twitter.com/jaypipes) or log an [Issue on Github](https://github.com/jaypipes/articles/issues) for this article.

[red]: https://placehold.it/15/f03c15/000000?text=+
[org]: https://placehold.it/15/ff9933/000000?text=+
[grn]: https://placehold.it/15/00cc00/000000?text=+
