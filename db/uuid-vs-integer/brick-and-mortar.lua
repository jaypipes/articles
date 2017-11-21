if sysbench.cmdline.command == nil then
    error("Command is required. Supported commands: prepare, warmup, run, " ..
          "cleanup, help")
end

sysbench.cmdline.options = {
    schema_design =
        {"Schema design to benchmark", "a"},
    num_products =
        {"Number of products to create", 1000},
    num_suppliers =
        {"Number of suppliers to create", 1000},
    num_customers =
        {"Number of customers to create", 10000},
    num_inventories =
        {"Number of inventory records create", 30000},
    num_orders =
        {"Number of orders to create", 40000},
    min_order_items =
        {"Min number of order items to create for an order", 1},
    max_order_items =
        {"Max number of order items to create for an order", 100},
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
    uuid VARCHAR(36) NOT NULL PRIMARY KEY,
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
    uuid VARCHAR(36) NOT NULL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT NULL,
    created_on DATETIME NOT NULL,
    updated_on DATETIME NULL
)
]],
        product_price_history = [[
CREATE TABLE IF NOT EXISTS product_price_history (
    product_uuid VARCHAR(36) NOT NULL,
    starting_on DATETIME NOT NULL,
    ending_on DATETIME NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (product_uuid, starting_on, ending_on)
)
]],
        inventories = [[
CREATE TABLE IF NOT EXISTS inventories (
    product_uuid VARCHAR(36) NOT NULL,
    supplier_uuid VARCHAR(36) NOT NULL,
    total INT NOT NULL,
    PRIMARY KEY (product_uuid, supplier_uuid),
    INDEX ix_supplier_uuid (supplier_uuid)
)
]],
        suppliers = [[
CREATE TABLE IF NOT EXISTS suppliers (
    uuid VARCHAR(36) NOT NULL PRIMARY KEY,
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
    uuid VARCHAR(36) NOT NULL PRIMARY KEY,
    customer_uuid VARCHAR(26) NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_on DATETIME NOT NULL,
    updated_on DATETIME NULL,
    INDEX ix_customer_uuid (customer_uuid)
)
]],
        order_details = [[
CREATE TABLE IF NOT EXISTS order_details (
    order_uuid VARCHAR(36) NOT NULL,
    product_uuid VARCHAR(36) NOT NULL,
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
    uuid VARCHAR(36) NOT NULL,
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
    description TEXT NULL
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
        orders = "INSERT INTO orders (id, customer_id, status, created_on, updated_on) VALUES (NULL, ?, ?, NOW(), NOW())"
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
        orders = "INSERT INTO orders (uuid, customer_uuid, status, created_on, updated_on) VALUES (UUID(), ?, ?, NOW(), NOW())"
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
        orders = "INSERT INTO orders (id, uuid, customer_id, status, created_on, updated_on) VALUES (NULL, UUID(), ?, ?, NOW(), NOW())"
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
]]
    }
}

function _init()
    drv = sysbench.sql.driver()
    con = drv:connect()
    drv_name = drv:name()

    if drv_name ~= "mysql" and drv_name ~= "postgresql" then
        error("Unsupported database driver:" .. drv_name)
    end
end

function _num_records_in_table(table_name)
    local num_recs = con:query_row("SELECT COUNT(*) FROM " .. table_name)
    return tonumber(num_recs)
end

function _create_schema(schema_design)
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

function _create_consumer_side(schema_design)
    local num_customers = _num_records_in_table('customers')
    local num_customers_needed = sysbench.opt.num_customers - num_customers

    print(string.format("PREPARE: found %d customer records.", num_customers))
    if num_customers_needed > 0 then
        _populate_customers(schema_design, num_customers_needed)
    end

    local num_orders = _num_records_in_table('orders')
    local num_orders_needed = sysbench.opt.num_orders - num_orders

    print(string.format("PREPARE: found %d order records.", num_orders))
    if num_orders_needed > 0 then
        _populate_orders(schema_design, num_orders_needed)
    end
end

function _populate_customers(schema_design, num_needed)
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
function _get_random_customer_batch(schema_design)
    local query = _select_queries[schema_design]['random_customer_batch']
    rs = con:query(query)
    customer_ids = {}
    for i = 1, rs.nrows do
        row = rs:fetch_row()
        table.insert(customer_ids, row[1])
    end
    return customer_ids
end

function _populate_orders(schema_design, num_needed)
    local orders_query = _insert_queries[schema_design]['orders']
    local orders_stmt = con:prepare(orders_query)
    local customer_param
    if schema_design ~= "b" then
        customer_param = orders_stmt:bind_create(sysbench.sql.type.INT)
    else
        customer_param = orders_stmt:bind_create(sysbench.sql.type.CHAR, 36)
    end
    local status_param = orders_stmt:bind_create(sysbench.sql.type.VARCHAR, 20)
    orders_stmt:bind_param(customer_param, status_param)

    local batch_n = 1000
    local created_n = 0
    while num_needed > 0 do
        local customers = _get_random_customer_batch(schema_design)
        if table.maxn(customers) == 0 then
            break
        end
        for cidx, customer_id in ipairs(customers) do
            local status = _create_order_status()
            if schema_design ~= "b" then
                customer_param:set(tonumber(customer_id))
            else
                customer_param:set(customer_id)
            end
            status_param:set(status)
            created_n = created_n + 1
            num_needed = num_needed - 1
            orders_stmt:execute()
        end
    end
    if created_n > 0 then
        print(string.format("PREPARE: created %d order records.", created_n))
    end
end

function _create_supply_side(schema_design)
    local num_products = _num_records_in_table('products')
    local num_products_needed = sysbench.opt.num_products - num_products

    print(string.format("PREPARE: found %d product records.", num_products))
    if num_products_needed > 0 then
        _populate_products(schema_design, num_products_needed)
    end

    local num_suppliers = _num_records_in_table('suppliers')
    local num_suppliers_needed = sysbench.opt.num_suppliers - num_suppliers

    print(string.format("PREPARE: found %d supplier records.", num_suppliers))
    if num_suppliers_needed > 0 then
        _populate_suppliers(schema_design, num_suppliers_needed)
    end

    local num_inventories = _num_records_in_table('inventories')
    local num_inventories_needed = sysbench.opt.num_inventories - num_inventories

    print(string.format("PREPARE: found %d inventory records.", num_inventories))
    if num_inventories_needed > 0 then
        _populate_inventories(schema_design, num_inventories_needed)
    end
end

function _populate_products(schema_design, num_needed)
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

function _populate_suppliers(schema_design, num_needed)
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
function _get_random_product_batch(schema_design)
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
function _get_random_supplier_batch(schema_design)
    local query = _select_queries[schema_design]['random_supplier_batch']
    rs = con:query(query)
    supplier_ids = {}
    for i = 1, rs.nrows do
        row = rs:fetch_row()
        table.insert(supplier_ids, row[1])
    end
    return supplier_ids
end

function _populate_inventories(schema_design, num_needed)
    local query = _insert_queries[schema_design]['inventories']
    local values_tpl = _insert_queries[schema_design]['inventories_values']

    local batch_n = 1000
    local created_n = 0
    while num_needed > 0 do
        -- Insert a set of inventory records for each product and supplier,
        -- with the number of products randomized between 1 amd the number of
        -- products in the system
        local products = _get_random_product_batch(schema_design)
        local suppliers = _get_random_supplier_batch(schema_design)
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
    local schema_design = sysbench.opt.schema_design
    _init()
    _create_schema(schema_design)
    _create_supply_side(schema_design)
    _create_consumer_side(schema_design)
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
