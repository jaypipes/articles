if sysbench.cmdline.command == nil then
    error("Command is required. Supported commands: prepare, warmup, run, " ..
          "cleanup, help")
end

-- TODO(jaypipes): Replace with C/FFI-based UUID generation
local uuid = require('db/uuid-vs-integer/uuid')

sysbench.cmdline.options = {
    schema_design =
        {"Schema design to benchmark", "a"},
    scenario =
        {"Scenario to benchmark", "customer_new_order"},
    num_products =
        {"Number of products to create", 1000},
    num_suppliers =
        {"Number of suppliers to create", 1000},
    num_customers =
        {"Number of customers to create", 5000},
    num_inventories =
        {"Number of inventory records create", 30000},
    num_orders =
        {"Number of orders to create", 10000},
    min_order_items =
        {"Min number of order items to create for an order", 1},
    max_order_items =
        {"Max number of order items to create for an order", 10},
}

-- Nested table of schema design to table name to the CREATE TABLE statement to
-- execute for that table
_schema = {
    a = {
        customers = [[
CREATE TABLE IF NOT EXISTS customers (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    address TEXT NOT NULL,
    state VARCHAR(20) NOT NULL,
    city VARCHAR(50) NOT NULL,
    postcode VARCHAR(20) NOT NULL,
    created_on DATETIME NOT NULL,
    updated_on DATETIME NULL
)
]],
        products = [[
CREATE TABLE IF NOT EXISTS products (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT NULL,
    created_on DATETIME NOT NULL,
    updated_on DATETIME NULL
)
]],
        product_price_history = [[
CREATE TABLE IF NOT EXISTS product_price_history (
    product_id INT NOT NULL,
    starting_on DATETIME NOT NULL,
    ending_on DATETIME NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (product_id, starting_on, ending_on)
)
]],
        inventories = [[
CREATE TABLE IF NOT EXISTS inventories (
    product_id INT NOT NULL,
    supplier_id INT NOT NULL,
    total INT NOT NULL,
    PRIMARY KEY (product_id, supplier_id),
    INDEX ix_supplier_id (supplier_id)
)
]],
        supplers = [[
CREATE TABLE IF NOT EXISTS suppliers (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    address TEXT NOT NULL,
    city VARCHAR(50) NOT NULL,
    state VARCHAR(20) NOT NULL,
    postcode VARCHAR(20) NOT NULL,
    created_on DATETIME NOT NULL,
    updated_on DATETIME NULL
)
]],
        orders = [[
CREATE TABLE IF NOT EXISTS orders (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_on DATETIME NOT NULL,
    updated_on DATETIME NULL,
    INDEX ix_customer_id (customer_id)
)
]],
        order_details = [[
CREATE TABLE IF NOT EXISTS order_details (
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    amount INT NOT NULL,
    fulfilling_supplier_id INT NOT NULL,
    PRIMARY KEY (order_id, product_id),
    KEY ix_product_id (product_id),
    KEY ix_fulfilling_supplier_id (fulfilling_supplier_id)
)
]]
    },
    b = {
        customers = [[
CREATE TABLE IF NOT EXISTS customers (
    uuid CHAR(36) NOT NULL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    address TEXT NOT NULL,
    state VARCHAR(20) NOT NULL,
    city VARCHAR(50) NOT NULL,
    postcode VARCHAR(20) NOT NULL,
    created_on DATETIME NOT NULL,
    updated_on DATETIME NULL
)
]],
        products = [[
CREATE TABLE IF NOT EXISTS products (
    uuid CHAR(36) NOT NULL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT NULL,
    created_on DATETIME NOT NULL,
    updated_on DATETIME NULL
)
]],
        product_price_history = [[
CREATE TABLE IF NOT EXISTS product_price_history (
    product_uuid CHAR(36) NOT NULL,
    starting_on DATETIME NOT NULL,
    ending_on DATETIME NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (product_uuid, starting_on, ending_on)
)
]],
        inventories = [[
CREATE TABLE IF NOT EXISTS inventories (
    product_uuid CHAR(36) NOT NULL,
    supplier_uuid CHAR(36) NOT NULL,
    total INT NOT NULL,
    PRIMARY KEY (product_uuid, supplier_uuid),
    INDEX ix_supplier_uuid (supplier_uuid)
)
]],
        suppliers = [[
CREATE TABLE IF NOT EXISTS suppliers (
    uuid CHAR(36) NOT NULL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    address TEXT NOT NULL,
    city VARCHAR(50) NOT NULL,
    state VARCHAR(20) NOT NULL,
    postcode VARCHAR(20) NOT NULL,
    created_on DATETIME NOT NULL,
    updated_on DATETIME NULL
)
]],
        orders = [[
CREATE TABLE IF NOT EXISTS orders (
    uuid CHAR(36) NOT NULL PRIMARY KEY,
    customer_uuid CHAR(36) NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_on DATETIME NOT NULL,
    updated_on DATETIME NULL,
    INDEX ix_customer_uuid (customer_uuid)
)
]],
        order_details = [[
CREATE TABLE IF NOT EXISTS order_details (
    order_uuid VARCHAR(36) NOT NULL,
    product_uuid CHAR(36) NOT NULL,
    amount INT NOT NULL,
    fulfilling_supplier_uuid VARCHAR(36) NOT NULL,
    PRIMARY KEY (order_uuid, product_uuid),
    KEY ix_product_id (product_uuid),
    KEY ix_fulfilling_supplier_uuid (fulfilling_supplier_uuid)
)
]]
    },
    c = {
        customers = [[
CREATE TABLE IF NOT EXISTS customers (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    uuid CHAR(36) NOT NULL,
    name VARCHAR(200) NOT NULL,
    address TEXT NOT NULL,
    state VARCHAR(20) NOT NULL,
    city VARCHAR(50) NOT NULL,
    postcode VARCHAR(20) NOT NULL,
    created_on DATETIME NOT NULL,
    updated_on DATETIME NULL,
    UNIQUE INDEX uix_uuid (uuid)
)
]],
        products = [[
CREATE TABLE IF NOT EXISTS products (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    uuid VARCHAR(36) NOT NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT NULL,
    created_on DATETIME NOT NULL,
    updated_on DATETIME NULL,
    UNIQUE INDEX uix_uuid (uuid)
)
]],
        product_price_history = [[
CREATE TABLE IF NOT EXISTS product_price_history (
    product_id INT NOT NULL,
    starting_on DATETIME NOT NULL,
    ending_on DATETIME NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (product_id, starting_on, ending_on)
)
]],
        inventories = [[
CREATE TABLE IF NOT EXISTS inventories (
    product_id INT NOT NULL,
    supplier_id INT NOT NULL,
    total INT NOT NULL,
    PRIMARY KEY (product_id, supplier_id),
    INDEX ix_supplier_id (supplier_id)
)
]],
        suppliers = [[
CREATE TABLE IF NOT EXISTS suppliers (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    uuid VARCHAR(36) NOT NULL,
    name VARCHAR(200) NOT NULL,
    address TEXT NOT NULL,
    city VARCHAR(50) NOT NULL,
    state VARCHAR(20) NOT NULL,
    postcode VARCHAR(20) NOT NULL,
    created_on DATETIME NOT NULL,
    updated_on DATETIME NULL,
    UNIQUE INDEX uix_uuid (uuid)
)
]],
        orders = [[
CREATE TABLE IF NOT EXISTS orders (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    uuid VARCHAR(36) NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_on DATETIME NOT NULL,
    updated_on DATETIME NULL,
    INDEX ix_customer_id (customer_id),
    UNIQUE INDEX uix_uuid (uuid)
)
]],
        order_details = [[
CREATE TABLE IF NOT EXISTS order_details (
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    amount INT NOT NULL,
    fulfilling_supplier_id INT NOT NULL,
    PRIMARY KEY (order_id, product_id),
    KEY ix_product_id (product_id),
    KEY ix_fulfilling_supplier_id (fulfilling_supplier_id)
)
]]
    }
}

_insert_queries = {
    a = {
        customers = "INSERT INTO customers (id, name, address, city, state, postcode, created_on, updated_on) VALUES",
        customers_values = "(NULL, '%s', '%s', '%s', '%s', '%s', NOW(), NOW())",
        products = "INSERT INTO products (id, name, description, created_on, updated_on) VALUES",
        products_values = "(NULL, '%s', '%s', NOW(), NOW())",
        suppliers = "INSERT INTO suppliers (id, name, address, city, state, postcode, created_on, updated_on) VALUES",
        suppliers_values = "(NULL, '%s', '%s', '%s', '%s', '%s', NOW(), NOW())",
        inventories = "INSERT INTO inventories (product_id, supplier_id, total) VALUES",
        inventories_values = "(%d, %d, %d)",
    },
    b = {
        customers = "INSERT INTO customers (uuid, name, address, city, state, postcode, created_on, updated_on) VALUES",
        customers_values = "(UUID(), '%s', '%s', '%s', '%s', '%s', NOW(), NOW())",
        products = "INSERT INTO products (uuid, name, description, created_on, updated_on) VALUES",
        products_values = "(UUID(), '%s', '%s', NOW(), NOW())",
        suppliers = "INSERT INTO suppliers (uuid, name, address, city, state, postcode, created_on, updated_on) VALUES",
        suppliers_values = "(UUID(), '%s', '%s', '%s', '%s', '%s', NOW(), NOW())",
        inventories = "INSERT INTO inventories (product_uuid, supplier_uuid, total) VALUES",
        inventories_values = "('%s', '%s', %d)",
    },
    c = {
        customers = "INSERT INTO customers (id, uuid, name, address, city, state, postcode, created_on, updated_on) VALUES",
        customers_values = "(NULL, UUID(), '%s', '%s', '%s', '%s', '%s', NOW(), NOW())",
        products = "INSERT INTO products (id, uuid, name, description, created_on, updated_on) VALUES",
        products_values = "(NULL, UUID(), '%s', '%s', NOW(), NOW())",
        suppliers = "INSERT INTO suppliers (id, uuid, name, address, city, state, postcode, created_on, updated_on) VALUES",
        suppliers_values = "(NULL, UUID(), '%s', '%s', '%s', '%s', '%s', NOW(), NOW())",
        inventories = "INSERT INTO inventories (product_id, supplier_id, total) VALUES",
        inventories_values = "(%d, %d, %d)",
    }
}

statements = {
    a = {
        insert_order = {
            sql = [[
INSERT INTO orders (id, customer_id, status, created_on, updated_on)
VALUES (NULL, ?, ?, NOW(), NOW())
]],
            binds = {
                sysbench.sql.type.INT,
                {sysbench.sql.type.VARCHAR, 20}
            }
        },
        insert_order_detail = {
            sql = [[
INSERT INTO order_details (order_id, product_id, fulfilling_supplier_id, amount)
VALUES (?, ?, ?, ?)
]],
            binds = {
                sysbench.sql.type.INT,
                sysbench.sql.type.INT,
                sysbench.sql.type.INT,
                sysbench.sql.type.INT
            }
        },
        select_orders_by_customer = {
            sql = [[
SELECT o.id, o.created_on, o.status, COUNT(*) AS num_items, SUM(od.amount) AS total_amount
FROM orders AS o
JOIN order_details AS od
 ON o.id = od.order_id
WHERE o.customer_id = ?
GROUP BY o.id
ORDER BY o.created_on DESC
]],
            binds = {
                sysbench.sql.type.INT
            }
        },
        select_most_popular_product_suppliers = {
            sql = [[
SELECT p.name, s.name, COUNT(DISTINCT o.id) AS included_in_orders, SUM(od.amount) AS total_purchased
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
]]
        }
    },
    b = {
        insert_order = {
            sql = [[
INSERT INTO orders (uuid, customer_uuid, status, created_on, updated_on)
VALUES (?, ?, ?, NOW(), NOW())
]],
            binds = {
                {sysbench.sql.type.CHAR, 36},
                {sysbench.sql.type.CHAR, 36},
                {sysbench.sql.type.VARCHAR, 20}
            }
        },
        insert_order_detail = {
            sql = [[
INSERT INTO order_details (order_uuid, product_uuid, fulfilling_supplier_uuid, amount)
VALUES (?, ?, ?, ?)
]],
            binds = {
                {sysbench.sql.type.CHAR, 36},
                {sysbench.sql.type.CHAR, 36},
                {sysbench.sql.type.CHAR, 36},
                sysbench.sql.type.INT
            }
        },
        select_orders_by_customer = {
            sql = [[
SELECT o.uuid, o.created_on, o.status, COUNT(*) AS num_items, SUM(od.amount) AS total_amount
FROM orders AS o
JOIN order_details AS od
 ON o.uuid = od.order_uuid
WHERE o.customer_uuid = ?
GROUP BY o.uuid
ORDER BY o.created_on DESC
]],
            binds = {
                {sysbench.sql.type.CHAR, 36},
            }
        },
        select_most_popular_product_suppliers = {
            sql = [[
SELECT p.name, s.name, COUNT(DISTINCT o.uuid) AS included_in_orders, SUM(od.amount) AS total_purchased
FROM orders AS o
JOIN order_details AS od
 ON o.uuid = od.order_uuid
JOIN products AS p
 ON od.product_uuid = p.uuid
JOIN suppliers AS s
 ON od.fulfilling_supplier_uuid = s.uuid
GROUP BY p.uuid, s.uuid
ORDER BY COUNT(DISTINCT o.uuid) DESC
LIMIT 100
]]
        }
    },
    c = {
        insert_order = {
            sql = [[
INSERT INTO orders (id, uuid, customer_id, status, created_on, updated_on)
VALUES (NULL, ?, ?, ?, NOW(), NOW())
]],
            binds = {
                {sysbench.sql.type.CHAR, 36},
                sysbench.sql.type.INT,
                {sysbench.sql.type.VARCHAR, 20}
            }
        },
        insert_order_detail = {
            sql = [[
INSERT INTO order_details (order_id, product_id, fulfilling_supplier_id, amount)
VALUES (?, ?, ?, ?)
]],
            binds = {
                sysbench.sql.type.INT,
                sysbench.sql.type.INT,
                sysbench.sql.type.INT,
                sysbench.sql.type.INT
            }
        },
        select_orders_by_customer = {
            sql = [[
SELECT o.uuid, o.created_on, o.status, COUNT(*) AS num_items, SUM(od.amount) AS total_amount
FROM orders AS o
JOIN order_details AS od
 ON o.id = od.order_id
JOIN customers AS c
 ON o.customer_id = c.id
WHERE c.uuid = ?
GROUP BY o.id
ORDER BY o.created_on DESC
]],
            binds = {
                {sysbench.sql.type.CHAR, 36},
            }
        },
        select_most_popular_product_suppliers = {
            sql = [[
SELECT p.name, s.name, COUNT(DISTINCT o.id) AS included_in_orders, SUM(od.amount) AS total_purchased
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
]]
        }
    }
}

_select_queries = {
    a = {
        random_product_batch = [[
SELECT p.id FROM products AS p
LEFT JOIN inventories AS i
 ON p.id = i.product_id
WHERE i.product_id IS NULL
GROUP BY p.id
ORDER BY RAND()
LIMIT 50
]],
        random_supplier_batch = [[
SELECT s.id FROM suppliers AS s
LEFT JOIN inventories AS i
 ON s.id = i.supplier_id
WHERE i.supplier_id IS NULL
GROUP BY s.id
ORDER BY RAND()
LIMIT 50
]],
        random_customer_batch = [[
SELECT c.id FROM customers AS c
ORDER BY RAND()
LIMIT 50
]],
        random_customer_external_ids = [[
SELECT c.id FROM customers AS c
ORDER BY RAND()
LIMIT 100
]],
        random_product_supplier_batch = [[
SELECT product_id, supplier_id
FROM inventories AS i
ORDER BY RAND()
LIMIT 200
]],
        fulfiller_for_product = [[
SELECT i.supplier_id
FROM inventories AS i
WHERE i.product_id = %d
ORDER BY i.total DESC
LIMIT 1
]],
        products_for_order = [[
SELECT i.product_id
FROM inventories AS i
GROUP BY i.product_id
ORDER BY RAND()
LIMIT %d
]]
    },
    b = {
        random_product_batch = [[
SELECT p.uuid FROM products AS p
LEFT JOIN inventories AS i
 ON p.uuid = i.product_uuid
WHERE i.product_uuid IS NULL
GROUP BY p.uuid
ORDER BY RAND()
LIMIT 50
]],
        random_supplier_batch = [[
SELECT s.uuid FROM suppliers AS s
LEFT JOIN inventories AS i
 ON s.uuid = i.supplier_uuid
WHERE i.supplier_uuid IS NULL
GROUP BY s.uuid
ORDER BY RAND()
LIMIT 50
]],
        random_customer_batch = [[
SELECT c.uuid FROM customers AS c
ORDER BY RAND()
LIMIT 50
]],
        random_customer_external_ids = [[
SELECT c.uuid FROM customers AS c
ORDER BY RAND()
LIMIT 100
]],
        random_product_supplier_batch = [[
SELECT product_uuid, supplier_uuid
FROM inventories AS i
ORDER BY RAND()
LIMIT 200
]],
        fulfiller_for_product = [[
SELECT i.supplier_uuid
FROM inventories AS i
WHERE i.product_uuid = '%s'
ORDER BY i.total DESC
LIMIT 1
]],
        products_for_order = [[
SELECT i.product_uuid
FROM inventories AS i
GROUP BY i.product_uuid
ORDER BY RAND()
LIMIT %d
]]
    },
    c = {
        random_product_batch = [[
SELECT p.id FROM products AS p
LEFT JOIN inventories AS i
 ON p.id = i.product_id
WHERE i.product_id IS NULL
GROUP BY p.id
ORDER BY RAND()
LIMIT 50
]],
        random_supplier_batch = [[
SELECT s.id FROM suppliers AS s
LEFT JOIN inventories AS i
 ON s.id = i.supplier_id
WHERE i.supplier_id IS NULL
GROUP BY s.id
ORDER BY RAND()
LIMIT 50
]],
        random_customer_batch = [[
SELECT c.id FROM customers AS c
ORDER BY RAND()
LIMIT 50
]],
        random_customer_external_ids = [[
SELECT c.uuid FROM customers AS c
ORDER BY RAND()
LIMIT 100
]],
        random_product_supplier_batch = [[
SELECT product_id, supplier_id
FROM inventories AS i
ORDER BY RAND()
LIMIT 200
]],
        fulfiller_for_product = [[
SELECT i.supplier_id
FROM inventories AS i
WHERE i.product_id = %d
ORDER BY i.total DESC
LIMIT 1
]],
        products_for_order = [[
SELECT i.product_id
FROM inventories AS i
GROUP BY i.product_id
ORDER BY RAND()
LIMIT %d
]],
        customer_internal_from_external = [[
SELECT c.id
FROM customers AS c
WHERE c.uuid = '%s'
]]
    }
}

function _init()
    drv = sysbench.sql.driver()
    con = drv:connect()
    drv_name = drv:name()
    schema_design = sysbench.opt.schema_design

    if drv_name ~= "mysql" and drv_name ~= "postgresql" then
        error("Unsupported database driver:" .. drv_name)
    end
end

function _num_records_in_table(table_name)
    local num_recs = con:query_row("SELECT COUNT(*) FROM " .. table_name)
    return tonumber(num_recs)
end

function _create_schema()
    print("PREPARE: ensuring database schema")

    for tbl, sql in pairs(_schema[schema_design]) do
        print("PREPARE: creating table " .. tbl)
        con:query(sql)
    end
end

-- I'd like to do a random string of some range of length, but can't do that
-- with sysbench's internal rand.string
name_tpl = "@@@@@@@@@@ @@@@@@@@@@@@@@@@@@@@@@@@@@@@"
description_tpl = "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
address_tpl = "@@@@@@@@@@@@@@@@\n@@@@@@@@@@@@@@\n@@@@@@@@@@@@"
city_tpl = "@@@@@@@@@@@@@@@@@@@@@@@@@@@"
state_tpl = "@@@@@@@@@@@@@@"
postcode_tpl = "@@@@@@"

function _create_consumer_side()
    local num_customers = _num_records_in_table('customers')
    local num_customers_needed = sysbench.opt.num_customers - num_customers

    print(string.format("PREPARE: found %d customer records.", num_customers))
    if num_customers_needed > 0 then
        _populate_customers(num_customers_needed)
    end

    local num_orders = _num_records_in_table('orders')
    local num_orders_needed = sysbench.opt.num_orders - num_orders

    print(string.format("PREPARE: found %d order records.", num_orders))
    if num_orders_needed > 0 then
        _populate_orders(num_orders_needed)
    end
end

function _populate_customers(num_needed)
    local query = _insert_queries[schema_design]['customers']
    local values_tpl = _insert_queries[schema_design]['customers_values']

    con:bulk_insert_init(query)
    for i = 1, num_needed do
        local c_name = sysbench.rand.string(name_tpl)
        local c_address = sysbench.rand.string(address_tpl)
        local c_city = sysbench.rand.string(city_tpl)
        local c_state = sysbench.rand.string(state_tpl)
        local c_postcode = sysbench.rand.string(postcode_tpl)
        local values = string.format(
            values_tpl,
            c_name, c_address, c_city, c_state, c_postcode
        )
        con:bulk_insert_next(values)
    end
    con:bulk_insert_done()
    print(string.format("PREPARE: created %d customer records.", num_needed))
end

_order_status_weighted = {
    'complete', 'complete', 'complete', 'complete', 'complete', 'complete', 'complete', 'complete',
    'complete', 'complete', 'complete', 'complete', 'complete', 'complete', 'complete', 'complete',
    'processing', 'processing',
    'pending',
    'shipping',
    'shipping',
    'canceled',
}
-- Returns a realistic order status based on a randomized selection of weighted
-- order statuses
function _create_order_status()
    num_statuses = table.maxn(_order_status_weighted)
    selected = sysbench.rand.uniform(1, num_statuses)
    return _order_status_weighted[selected]
end

-- Get a batch of random customer identifiers. Note this isn't a quick
-- operation doing ORDER BY RANDOM(), but this is only done in the prepare step
-- so we should be OK
function _get_random_customer_batch()
    local query = _select_queries[schema_design]['random_customer_batch']
    local rs = con:query(query)
    local customers = {}
    for i = 1, rs.nrows do
        row = rs:fetch_row()
        customer = row[1]
        if schema_design ~= "b" then
            customer = tonumber(customer)
        end
        table.insert(customers, customer)
    end
    return customers
end

-- Get a batch of random product and supplier identifier pairs. Used when
-- creating a bunch of order details for customers during the prepare stage
function _get_random_product_supplier_batch()
    local query = _select_queries[schema_design]['random_product_supplier_batch']
    local rs = con:query(query)
    local product_suppliers = {}
    for i = 1, rs.nrows do
        row = rs:fetch_row()
        product = row[1]
        supplier = row[2]
        if schema_design ~= "b" then
            product = tonumber(product)
            supplier = tonumber(supplier)
        end
        table.insert(product_suppliers, {product, supplier})
    end
    return product_suppliers
end

-- Creates the prepared statement for the schema design and named statement by
-- looking in the statements table variable and binding parameters described
-- for the named statement to the prepared statement pointer. Returns the table
-- object containing a "statement" key containing the prepared statement
-- pointer and a "params" array of bound parameter pointers
function _prepare_statement(stmt_name)
    stmt_tbl = statements[schema_design][stmt_name]
    assert(stmt_tbl ~= nil)
    stmt = con:prepare(stmt_tbl.sql)
    if stmt_tbl.binds ~= nil and table.maxn(stmt_tbl.binds) then
        stmt_tbl.params = {}
        for idx, bind in ipairs(stmt_tbl.binds) do
            if type(bind) ~= "table" then
                -- Convenience, allows us to have non-array bind parameter
                -- descriptors in the statements table
                bind = {bind}
            end
            param = stmt:bind_create(unpack(bind))
            stmt_tbl.params[idx] = param
        end
        stmt:bind_param(unpack(stmt_tbl.params))
    end
    statements[schema_design][stmt_name].statement = stmt
    return stmt_tbl
end

function _populate_orders(num_needed)
    order_stmt_tbl = _prepare_statement('insert_order')
    order_stmt = order_stmt_tbl.statement
    order_stmt_params = order_stmt_tbl.params
    order_detail_stmt_tbl = _prepare_statement('insert_order_detail')
    order_detail_stmt = order_detail_stmt_tbl.statement
    order_detail_stmt_params = order_detail_stmt_tbl.params

    local created_orders = 0
    local created_order_details = 0
    while num_needed > 0 do
        local customers = _get_random_customer_batch()
        if table.maxn(customers) == 0 then
            break
        end
        local product_suppliers = _get_random_product_supplier_batch()
        if table.maxn(product_suppliers) == 0 then
            break
        end
        local max_products = table.maxn(product_suppliers)
        for cidx, customer in ipairs(customers) do
            local status = _create_order_status()
            local order_id = nil
            if schema_design == "a" then
                order_stmt_params[1]:set(customer)
                order_stmt_params[2]:set(status)
            else
                order_id = uuid.new()
                order_stmt_params[1]:set(order_id)
                order_stmt_params[2]:set(customer)
                order_stmt_params[3]:set(status)
            end
            created_orders = created_orders + 1
            num_needed = num_needed - 1
            order_stmt:execute()

            if schema_design ~= "b" then
                order_id = con:query_row("SELECT LAST_INSERT_ID()")
                order_id = tonumber(order_id)
            end

            -- Now add some items to the order as order_details records
            local num_items = sysbench.rand.uniform(sysbench.opt.min_order_items, sysbench.opt.max_order_items)
            local products_in_order = {}
            local circuit_breaker = 1
            repeat
                -- Grab a random product/supplier combo and generate a random
                -- quantity of items
                local selected = sysbench.rand.uniform(1, max_products)
                local amount = sysbench.rand.uniform(1, 100)
                local product = product_suppliers[selected][1]
                local supplier = product_suppliers[selected][2]
                -- Make sure we haven't added an item with this product before...
                local already_in_order = false
                for idx, p in ipairs(products_in_order) do
                    if product == p then
                        already_in_order = true
                    end
                end
                if not already_in_order then
                    table.insert(products_in_order, product)
                    order_detail_stmt_params[1]:set(order_id)
                    order_detail_stmt_params[2]:set(product)
                    order_detail_stmt_params[3]:set(supplier)
                    order_detail_stmt_params[4]:set(amount)
                    order_detail_stmt:execute()
                    created_order_details = created_order_details + 1
                end
                -- A little infinite loop safety....
                circuit_breaker = circuit_breaker + 1
                if circuit_breaker > (num_items + 50) then
                    break
                end
            until table.maxn(products_in_order) == num_items
        end
    end
    if created_orders > 0 then
        print(string.format("PREPARE: created %d order records with %d details.", created_orders, created_order_details))
    end
end

function _create_supply_side()
    local num_products = _num_records_in_table('products')
    local num_products_needed = sysbench.opt.num_products - num_products

    print(string.format("PREPARE: found %d product records.", num_products))
    if num_products_needed > 0 then
        _populate_products(num_products_needed)
    end

    local num_suppliers = _num_records_in_table('suppliers')
    local num_suppliers_needed = sysbench.opt.num_suppliers - num_suppliers

    print(string.format("PREPARE: found %d supplier records.", num_suppliers))
    if num_suppliers_needed > 0 then
        _populate_suppliers(num_suppliers_needed)
    end

    local num_inventories = _num_records_in_table('inventories')
    local num_inventories_needed = sysbench.opt.num_inventories - num_inventories

    print(string.format("PREPARE: found %d inventory records.", num_inventories))
    if num_inventories_needed > 0 then
        _populate_inventories(num_inventories_needed)
    end
end

function _populate_products(num_needed)
    local query = _insert_queries[schema_design]['products']
    local values_tpl = _insert_queries[schema_design]['products_values']

    con:bulk_insert_init(query)
    for i = 1, num_needed do
        local c_name = sysbench.rand.string(name_tpl)
        local c_description = sysbench.rand.string(description_tpl)
        local values = string.format(
            values_tpl, c_name, c_description
        )
        con:bulk_insert_next(values)
    end
    con:bulk_insert_done()
    print(string.format("PREPARE: created %d product records.", num_needed))
end

function _populate_suppliers(num_needed)
    local query = _insert_queries[schema_design]['suppliers']
    local values_tpl = _insert_queries[schema_design]['suppliers_values']

    con:bulk_insert_init(query)
    for i = 1, num_needed do
        local c_name = sysbench.rand.string(name_tpl)
        local c_address = sysbench.rand.string(address_tpl)
        local c_city = sysbench.rand.string(city_tpl)
        local c_state = sysbench.rand.string(state_tpl)
        local c_postcode = sysbench.rand.string(postcode_tpl)
        local values = string.format(
            values_tpl,
            c_name, c_address, c_city, c_state, c_postcode
        )
        con:bulk_insert_next(values)
    end
    con:bulk_insert_done()
    print(string.format("PREPARE: created %d supplier records.", num_needed))
end

-- Get a batch of random product identifiers that are not already in
-- inventories table. Note this isn't a quick operation doing ORDER BY
-- RANDOM(), but this is only done in the prepare step so we should be OK
function _get_random_product_batch()
    local query = _select_queries[schema_design]['random_product_batch']
    rs = con:query(query)
    product_ids = {}
    for i = 1, rs.nrows do
        row = rs:fetch_row()
        table.insert(product_ids, row[1])
    end
    return product_ids
end

-- Get a batch of random supplier identifiers that are not already in
-- inventories table. Note this isn't a quick operation doing ORDER BY
-- RANDOM(), but this is only done in the prepare step so we should be OK
function _get_random_supplier_batch()
    local query = _select_queries[schema_design]['random_supplier_batch']
    rs = con:query(query)
    supplier_ids = {}
    for i = 1, rs.nrows do
        row = rs:fetch_row()
        table.insert(supplier_ids, row[1])
    end
    return supplier_ids
end

function _populate_inventories(num_needed)
    local query = _insert_queries[schema_design]['inventories']
    local values_tpl = _insert_queries[schema_design]['inventories_values']

    local batch_n = 1000
    local created_n = 0
    while num_needed > 0 do
        -- Insert a set of inventory records for each product and supplier,
        -- with the number of products randomized between 1 amd the number of
        -- products in the system
        local products = _get_random_product_batch()
        local suppliers = _get_random_supplier_batch()
        if table.maxn(products) == 0 or table.maxn(suppliers) == 0 then
            break
        end
        for sidx, supplier_id in ipairs(suppliers) do
            con:bulk_insert_init(query)
            local num_products = sysbench.rand.uniform(1, sysbench.opt.num_products)
            if num_products > table.maxn(products) then
                num_products = table.maxn(products)
            end
            for i = 1, num_products do
                local product_id = products[i]
                local total = sysbench.rand.uniform(1, 1000)
                local values = string.format(values_tpl, product_id, supplier_id, total)
                con:bulk_insert_next(values)
                created_n = created_n + 1
                num_needed = num_needed - 1
                batch_n = batch_n - 1
                if batch_n == 0 then
                    con:bulk_insert_done()
                    con:bulk_insert_init(query)
                    batch_n = 1000
                end
            end
            con:bulk_insert_done()
        end
    end
    if created_n > 0 then
        print(string.format("PREPARE: created %d inventory records.", created_n))
    end
end

-- Creates the schema tables and populates the tables with data up to the
-- required record counts taken from the command-line options
function prepare()
    _init()
    _create_schema()
    _create_supply_side()
    _create_consumer_side()
end

-- Completely removes and re-creates the database/catalog being used for
-- testing
function cleanup()
    _init()

    -- TODO(jayupipes): Support PostgreSQL schema/catalog name in sysbench
    local schema_name = sysbench.opt.mysql_db

    print("CLEANUP: dropping and recreating schema " .. schema_name)

    if drv_name == 'mysql' then
        con:query("DROP SCHEMA IF EXISTS `" .. sysbench.opt.mysql_db .. "`")
        con:query("CREATE SCHEMA `" .. sysbench.opt.mysql_db .. "`")
    end
end

-- Returns a batch of 100 random external customer IDs
function _get_customer_external_ids()
    local query = _select_queries[schema_design]['random_customer_external_ids']
    local rs = con:query(query)
    local customers = {}
    for i = 1, rs.nrows do
        row = rs:fetch_row()
        table.insert(customers, row[1])
    end
    return customers
end

function thread_init()
    _init()
    -- uuid.new() isn't thread-safe -- it creates the same set of UUIDs in
    -- order for each thread -- so we trick it into creating a "new" UUID by
    -- creating a new fake MAC address per thread
    thread_mac = sysbench.rand.string('##:##:##:##:##:##')
    scenario = sysbench.opt.scenario
    customers = _get_customer_external_ids()
    scenario_stmts = _prepare_scenario(scenario)
end

scenarios = {
    lookup_orders_by_customer = {
        statements = {
            'select_orders_by_customer'
        }
    },
    popular_items = {
        statements = {
            'select_most_popular_product_suppliers'
        }
    },
    customer_new_order = {
        statements = {
            'insert_order',
            'insert_order_detail'
        }
    }
}

-- Creates the prepared statements for the schema design and named scenario by
-- looking in the scenarios table variable and binding parameters described for
-- each named scenario's set of prepared statements to the prepared statement
-- pointer. Returns the table object containing a "statements" key which is a
-- table containing a "statement" key that contains the prepared statement
-- pointer and a "params" array of bound parameter pointers
function _prepare_scenario(scenario)
    scenario_tbl = scenarios[scenario]
    assert(scenario_tbl ~= nil)

    local scenario_stmts = {}

    for st_idx, stmt_name in ipairs(scenario_tbl.statements) do
        stmt_tbl = _prepare_statement(stmt_name)
        scenario_stmts[st_idx] = stmt_tbl
    end
    return scenario_stmts
end

-- Returns a supplier internal identifier that will fulfill the supplied
-- external product identifier
function get_fulfiller_for_product(product)
    local query = _select_queries[schema_design]['fulfiller_for_product']
    query = string.format(query, product)
    local supplier = con:query_row(query)
    if schema_design ~= "b" then
        supplier = tonumber(supplier)
    end
    return supplier
end

-- Returns a number of random product external identifiers. Meant to simulate a
-- customer selecting some number of items to purchase through the store and
-- needing to supply those external product identifiers to the order system for
-- processing the order details.
function get_products_for_order(num_products)
    local query = _select_queries[schema_design]['products_for_order']
    query = string.format(query, num_products)
    local rs = con:query(query)
    local products = {}
    for i = 1, rs.nrows do
        local row = rs:fetch_row()
        local product = row[1]
        if schema_design ~= "b" then
            product = tonumber(product)
        end
        table.insert(products, product)
    end
    return products
end

-- Returns the internal customer ID from the external customer ID
function get_customer_internal_from_external(external)
    local query = _select_queries[schema_design]['customer_internal_from_external']
    query = string.format(query, external)
    local internal = con:query_row(query)
    if schema_design == "c" then
        internal = tonumber(internal)
    end
    return internal
end

-- Creates a single order for the supplied customer external ID and array of
-- external product IDs. A random quantity of each product is ordered.
function customer_new_order(customer, products, order_uuid)
    local ins_order = scenario_stmts[1]
    local ins_order_det = scenario_stmts[2]

    local status = _create_order_status()
    local order_id = nil
    local customer_id = customer
    if schema_design == "a" then
        ins_order.params[1]:set(customer_id)
        ins_order.params[2]:set(status)
    else
        order_id = uuid.new(thread_mac)
        -- For schema design "c", the tradeoff is we need to do a secondary key
        -- lookup on the external customer UUID to get the internal customer ID
        if schema_design == "c" then
            customer_id = get_customer_internal_from_external(customer)
        end
        ins_order.params[1]:set(order_id)
        ins_order.params[2]:set(customer_id)
        ins_order.params[3]:set(status)
    end

    ins_order.statement:execute()

    if schema_design ~= "b" then
        order_id = con:query_row("SELECT LAST_INSERT_ID()")
        order_id = tonumber(order_id)
    end

    for idx, product in ipairs(products) do
        local amount = sysbench.rand.uniform(1, 100)
        local supplier = get_fulfiller_for_product(product)
        ins_order_det.params[1]:set(order_id)
        ins_order_det.params[2]:set(product)
        ins_order_det.params[3]:set(supplier)
        ins_order_det.params[4]:set(amount)
        ins_order_det.statement:execute()
    end
end

function execute_lookup_orders_by_customer()
    local selected = sysbench.rand.uniform(1, table.maxn(customers))
    local customer = customers[selected]
    if schema_design == "a" then
        customer = tonumber(customer)
    end

    for st_idx, stmt in ipairs(scenario_stmts) do
        stmt.params[1]:set(customer)
        stmt.statement:execute()
    end
end

function execute_popular_items()
    for st_idx, stmt in ipairs(scenario_stmts) do
        stmt.statement:execute()
    end
end

function execute_customer_new_order()
    local selected = sysbench.rand.uniform(1, table.maxn(customers))
    local customer = customers[selected]
    if schema_design == "a" then
        customer = tonumber(customer)
    end
    local num_items = sysbench.rand.uniform(sysbench.opt.min_order_items, sysbench.opt.max_order_items)
    local products = get_products_for_order(num_items)
    customer_new_order(customer, products)
end

function event()
    if scenario == 'lookup_orders_by_customer' then
        execute_lookup_orders_by_customer()
    elseif scenario == 'popular_items' then
        execute_popular_items()
    elseif scenario == 'customer_new_order' then
        execute_customer_new_order()
    end
end

function thread_done()
    return
end
