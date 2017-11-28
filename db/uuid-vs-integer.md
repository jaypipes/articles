# Investigation into UUID vs. integer database performance

There have been a number of articles over the past five years or so that
describe some of the benefits, costs and potential pitfalls of using UUID
values as primary keys for database tables instead of the more traditional
auto-incrementing integer primary key.

Each of these articles tends to include some interesting graphs, but nearly all
of them focus on two metrics for benchmark data: the speed of `INSERT` and the
size of the table data and index data segments. While these metrics are both
very important, focusing on them exclusively means that there are some critical
points left out from the overall discussion of application performance and
query efficiency.

This article aims to provide a thorough comparison of UUID and integer field
performance. We'll be examining schemas that represent real-world application
scenarios and run a series of comparative benchmarks that demonstrate the
impact of using one strategy over another.

1. [Overview](#overview)
1. [Application database schemas](#application-databases)
    1. [Brick-and-mortar store](#brick-and-mortar-store)
    1. [Employee Directory](#employee-directory)
1. [Schema design strategies](#schema-design-strategies)
    1. [A: Auto-inc integer PK, no UUIDs](#schema-design-a-auto-incrementing-integer-primary-key-no-uuids)
    1. [B: UUID PK](#schema-design-b-uuid-pk)
    1. [C: Auto-inc integer PK, external UUIDs](#schema-design-c-auto-incrementing-integer-primary-key-external-uuids)
1. [Application data patterns](#application-data-patterns)
    1. [Data-access patterns](#data-access-patterns)
    1. [Data-write patterns](#data-write-patterns)
1. [Database server-configurations](#database-server-configurations)
    1. [MySQL Server](#mysql-server)
    1. [PostgreSQL](#postgresql)

## Overview

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
why this article uses two archetypal applications in order to illustrate
real-world application query patterns.

We aim to answer a series of questions about the impact of using UUIDs versus
integer columns in the underlying database schema. These questions will examine
differences in read and write query performance as well as implications to
scale-out and partitioning.

## Application database schemas

I've tried as much as possible to do the comparison tests and benchmarks in
this article against database schemas that represent realistic applications
that might use an RDBMS for primary backend storage. To explore all the data
access patterns I wanted to explore, I created two different application
schemas, one for a "brick-and-mortar store" and another for a representing a
large hierarchical organization's employee directory.

### Brick and mortar store

The brick-and-mortar store point-of-sale application is all about recording
information for an imaginary home-goods store: orders, customer, suppliers,
products, etc.

![brick-and-mortar store E-R diagram](uuid-vs-integer/images/brick-and-mortar-e-r.png "Entity-relationship diagram for brick-and-mortar store application")

### Employee directory

The employee directory application models a large organization's need for
employees to be able to find information about employees and the structure of
the organization. This schema and application will be used in comparing the
performance of queries involving self-referential tables and hierarchical graph
data.

![employee directory E-R diagram](uuid-vs-integer/images/employee-directory-e-r.png "Entity-relationship diagram for employee directory application")

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

For MySQL, this means that tables in the application schemas are all defined
with an `id` column as the primary key in the following manner:

```sql
CREATE TABLE products (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  ...
);
```

For PostgreSQL, this means tables in the application schemas are all defined
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

For MySQL, this means that tables in the application schemas are all defined
with a `uuid` column as the primary key in the following manner:

```sql
CREATE TABLE products (
  uuid CHAR(36) NOT NULL PRIMARY KEY,
  ...
);
```

For PostgreSQL, this means tables in the application schemas are all defined
with an `uuid` column as the primary key in the following manner:

```sql
CREATE TABLE products (
  id UUID NOT NULL PRIMARY KEY,
  ...
);
```

Note that PostgreSQL has a native UUID type.

### Schema design C: Auto-incrementing integer primary key, UUID externals

Schema Design "C" represents a database design strategy that uses
auto-incrementing integers as the primary key for entities, but these integer
keys are not exposed to users. Instead, UUIDs are used as the identifiers that
application users utilize to look up specific records in the application.

In other words, there is a secondary unique constraint/key on a UUID column for
each table in the schema.

For MySQL, this means that tables in the application schemas are all defined
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

For PostgreSQL, this means that tables in the application schemas are all
defined with an `id` column as the primary key and a `uuid` secondary key in
the following manner:

```sql
CREATE TABLE products (
  id SERIAL NOT NULL PRIMARY KEY,
  uuid UUID NOT NULL UNIQUE,
  ...
);
```

## Application data patterns

As mentioned above, I wanted to show the impact of these schema designs/choices
in **real-world applications**. To that point, I developed a number benchmark
scenarios that I thought represented some realistic data access and data write
patterns.

For the brick-and-mortar application, I came up with these scenarios:

* `customer_new_order`
* `lookup_orders_by_customer`
* `popular_items`

Following is an explanation of each scenario and the SQL statements from which
the scenario is composed.

* Single-table external key lookup
* Multi-table external key lookup
* Self-referential single-table lookup
* Self-referential multi-table lookup
* Batched INSERTs, minimal UPDATEs or DELETEs
* Single-record INSERTs, UPDATEs, and DELETEs
* Multi-table transactions

### `customer_new_order`

The `customer_new_order` scenario comes from the brick-and-mortar application.
It is intended to emulate a single customer making a purchase of items in the
store.

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

For schema design "C", this also accurately stresses the impact of needing to
do one additional "point select" query for grabbing the internal customer ID
from the external customer UUID.

For schema designs "A" and "C", it also represents the need to perform an
additional query to retrieve the newly-created order's auto-incrementing
primary key before inserting order detail records. This step does not need to
be done for schema design "B" since the UUID is generated ahead of order record
creation.

### `lookup_orders_by_customer`

The `lookup_orders_by_customer` scenario comes from the brick-and-mortar
application and is designed to emulate a query that would be run by a customer
service representative when a customer comes into the store and needs to find
some order information.

This scenario only entails a single `SELECT` query, but the query is designed
to stress a particular archetypal data access pattern: aggregating information
across a set of columns in a child table used in a secondary index (product and
supplier columns) while filtering records also on a secondary index in a parent
table (customer).

This query looks like this for schema design "A":

```sql
SELECT o.id, o.created_on, o.status, COUNT(*) AS num_items, SUM(od.quantity * od.price) AS total_amount
FROM orders AS o
JOIN order_details AS od
 ON o.id = od.order_id
WHERE o.customer_id = ?
GROUP BY o.id
ORDER BY o.created_on DESC
```

for schema design "B", the query is as follows:

```sql
SELECT o.uuid, o.created_on, o.status, COUNT(*) AS num_items, SUM(od.quantity * od.price) AS total_amount
FROM orders AS o
JOIN order_details AS od
 ON o.uuid = od.order_uuid
WHERE o.customer_uuid = ?
GROUP BY o.uuid
ORDER BY o.created_on DESC
```

and finally, for schema design "C", the query looks like this:

```sql
SELECT o.uuid, o.created_on, o.status, COUNT(*) AS num_items, SUM(od.quantity * od.price) AS total_amount
FROM orders AS o
JOIN order_details AS od
 ON o.id = od.order_id
JOIN customers AS c
 ON o.customer_id = c.id
WHERE c.uuid = ?
GROUP BY o.id
ORDER BY o.created_on DESC
```

Note that for schema design "C", since we use the UUID as the external
identifier for the customer, we need to join to the `customers` table in order to
query on the customer's UUID value. Since the UUID *is* the primary key in
schema design "B" and the auto-incrementing integer *is* the primary key in
schema design "A", those queries need not join to the `customers` table.

### `popular_items`

The `popular_items` scenario, from the brick-and-mortar application, includes a
single `SELECT` statement that might be run by an extract-transform-load (ETL)
tool or an online analytical processing (OLAP) program.

For the general manager of our brick-and-mortar store, she might want to know
which are the best-selling products and which suppliers are providing those
products.

The `SELECT` expression for this query looks like this:

```sql
SELECT p.name, s.name, COUNT(DISTINCT o.id) AS included_in_orders, SUM(od.quantity * od.price) AS total_purchased
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

Note that there is no `WHERE` clause on the above, which means that there will
end up being a full table scan of the `order_details`. I've specifically
designed this query to show the impact that the choice of using UUID or
auto-incrementing primary keys has on sequential read performance.

## Database server configurations

This article runs a series of tests against a set of open source database
server configurations to see if there are noteworthy differences between the
performance of our schema design strategies.

The database server configurations we test are the following:

* MySQL Server 5.7 with InnoDB storage engine
* PostgreSQL 9.6

### MySQL Server

TODO

### PostgreSQL

TODO
