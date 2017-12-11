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
    mysql = {
        {
            "customers", [[
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
]]
        },
        {
            "products", [[
CREATE TABLE IF NOT EXISTS products (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT NULL,
    created_on DATETIME NOT NULL,
    updated_on DATETIME NULL
)
]]
        },
        {
            "product_price_history", [[
CREATE TABLE IF NOT EXISTS product_price_history (
    product_id INT NOT NULL,
    starting_on DATETIME NOT NULL,
    ending_on DATETIME NOT NULL,
    price DOUBLE NOT NULL,
    PRIMARY KEY (product_id, starting_on, ending_on)
)
]]
        },
        {
            "inventories", [[
CREATE TABLE IF NOT EXISTS inventories (
    product_id INT NOT NULL,
    supplier_id INT NOT NULL,
    total INT NOT NULL,
    PRIMARY KEY (product_id, supplier_id),
    INDEX ix_supplier_id (supplier_id)
)
]]
        },
        {
            "supplers", [[
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
]]
        },
        {
            "orders", [[
CREATE TABLE IF NOT EXISTS orders (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_on DATETIME NOT NULL,
    updated_on DATETIME NULL,
    INDEX ix_status (status),
    INDEX ix_customer_id (customer_id)
)
]]
        },
        {
            "order_details", [[
CREATE TABLE IF NOT EXISTS order_details (
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    price DOUBLE NOT NULL,
    fulfilling_supplier_id INT NOT NULL,
    PRIMARY KEY (order_id, product_id),
    KEY ix_product_fulfilling_supplier_id (product_id, fulfilling_supplier_id),
    KEY ix_fulfilling_supplier_id (fulfilling_supplier_id)
)
]]
        }
    },
    pgsql = {
        {
            "customers", [[
CREATE TABLE IF NOT EXISTS customers (
    id SERIAL NOT NULL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    address TEXT NOT NULL,
    state VARCHAR(20) NOT NULL,
    city VARCHAR(50) NOT NULL,
    postcode VARCHAR(20) NOT NULL,
    created_on TIMESTAMP NOT NULL,
    updated_on TIMESTAMP NULL
)
]]
        },
        {
            "products", [[
CREATE TABLE IF NOT EXISTS products (
    id SERIAL NOT NULL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT NULL,
    created_on TIMESTAMP NOT NULL,
    updated_on TIMESTAMP NULL
)
]]
        },
        {
            "product_price_history", [[
CREATE TABLE IF NOT EXISTS product_price_history (
    product_id SERIAL NOT NULL,
    starting_on TIMESTAMP NOT NULL,
    ending_on TIMESTAMP NOT NULL,
    price NUMERIC NOT NULL,
    PRIMARY KEY (product_id, starting_on, ending_on)
)
]]
        },
        {
            "inventories", [[
CREATE TABLE IF NOT EXISTS inventories (
    product_id SERIAL NOT NULL,
    supplier_id SERIAL NOT NULL,
    total INT NOT NULL,
    PRIMARY KEY (product_id, supplier_id)
)
]]
        },
        {
            "inventories_idx", [[
CREATE INDEX ix_supplier_id ON inventories (supplier_id)
]]
        },
        {
            "supplers", [[
CREATE TABLE IF NOT EXISTS suppliers (
    id SERIAL NOT NULL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    address TEXT NOT NULL,
    city VARCHAR(50) NOT NULL,
    state VARCHAR(20) NOT NULL,
    postcode VARCHAR(20) NOT NULL,
    created_on TIMESTAMP NOT NULL,
    updated_on TIMESTAMP NULL
)
]]
        },
        {
            "orders", [[
CREATE TABLE IF NOT EXISTS orders (
    id SERIAL NOT NULL PRIMARY KEY,
    customer_id SERIAL NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_on TIMESTAMP NOT NULL,
    updated_on TIMESTAMP NULL
)
]]
        },
        {
            "orders_idx_status", [[
CREATE INDEX ix_status ON orders (status)
]]
        },
        {
            "orders_idx_customer_id", [[
CREATE INDEX ix_customer_id ON orders (customer_id)
]]
        },
        {
            "order_details", [[
CREATE TABLE IF NOT EXISTS order_details (
    order_id SERIAL NOT NULL,
    product_id SERIAL NOT NULL,
    quantity INT NOT NULL,
    price NUMERIC NOT NULL,
    fulfilling_supplier_id SERIAL NOT NULL,
    PRIMARY KEY (order_id, product_id)
)
]]
        },
        {
            "order_details_idx_product_fulfilling_supplier_id", [[
CREATE INDEX ix_product_fulfilling_supplier_id ON order_details (product_id, fulfilling_supplier_id)
]]
        },
        {
            "order_details_idx_fulfilling_supplier_id", [[
CREATE INDEX ix_fulfilling_supplier_id ON order_details (fulfilling_supplier_id)
]]
        }
    }
},
b = {
    mysql = {
        {
            "customers", [[
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
]]
        },
        {
            "products", [[
CREATE TABLE IF NOT EXISTS products (
    uuid CHAR(36) NOT NULL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT NULL,
    created_on DATETIME NOT NULL,
    updated_on DATETIME NULL
)
]]
        },
        {
            "product_price_history", [[
CREATE TABLE IF NOT EXISTS product_price_history (
    product_uuid CHAR(36) NOT NULL,
    starting_on DATETIME NOT NULL,
    ending_on DATETIME NOT NULL,
    price DOUBLE NOT NULL,
    PRIMARY KEY (product_uuid, starting_on, ending_on)
)
]]
        },
        {
            "inventories", [[
CREATE TABLE IF NOT EXISTS inventories (
    product_uuid CHAR(36) NOT NULL,
    supplier_uuid CHAR(36) NOT NULL,
    total INT NOT NULL,
    PRIMARY KEY (product_uuid, supplier_uuid),
    INDEX ix_supplier_uuid (supplier_uuid)
)
]]
        },
        {
            "suppliers", [[
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
]]
        },
        {
            "orders", [[
CREATE TABLE IF NOT EXISTS orders (
    uuid CHAR(36) NOT NULL PRIMARY KEY,
    customer_uuid CHAR(36) NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_on DATETIME NOT NULL,
    updated_on DATETIME NULL,
    INDEX ix_status (status),
    INDEX ix_customer_uuid (customer_uuid)
)
]]
        },
        {
            "order_details", [[
CREATE TABLE IF NOT EXISTS order_details (
    order_uuid VARCHAR(36) NOT NULL,
    product_uuid CHAR(36) NOT NULL,
    quantity INT NOT NULL,
    price DOUBLE NOT NULL,
    fulfilling_supplier_uuid VARCHAR(36) NOT NULL,
    PRIMARY KEY (order_uuid, product_uuid),
    KEY ix_product_fulfilling_supplier_uuid (product_uuid, fulfilling_supplier_uuid),
    KEY ix_fulfilling_supplier_uuid (fulfilling_supplier_uuid)
)
]]
        }
    },
    pgsql = {
        {
            "customers", [[
CREATE TABLE IF NOT EXISTS customers (
    uuid UUID NOT NULL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    address TEXT NOT NULL,
    state VARCHAR(20) NOT NULL,
    city VARCHAR(50) NOT NULL,
    postcode VARCHAR(20) NOT NULL,
    created_on TIMESTAMP NOT NULL,
    updated_on TIMESTAMP NULL
)
]]
        },
        {
            "products", [[
CREATE TABLE IF NOT EXISTS products (
    uuid UUID NOT NULL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT NULL,
    created_on TIMESTAMP NOT NULL,
    updated_on TIMESTAMP NULL
)
]]
        },
        {
            "product_price_history", [[
CREATE TABLE IF NOT EXISTS product_price_history (
    product_uuid UUID NOT NULL,
    starting_on TIMESTAMP NOT NULL,
    ending_on TIMESTAMP NOT NULL,
    price NUMERIC NOT NULL,
    PRIMARY KEY (product_uuid, starting_on, ending_on)
)
]]
        },
        {
            "inventories", [[
CREATE TABLE IF NOT EXISTS inventories (
    product_uuid UUID NOT NULL,
    supplier_uuid UUID NOT NULL,
    total INT NOT NULL,
    PRIMARY KEY (product_uuid, supplier_uuid)
)
]]
        },
        {
            "inventories_idx", [[
CREATE INDEX ix_supplier_uuid ON inventories (supplier_uuid)
]]
        },
        {
            "supplers", [[
CREATE TABLE IF NOT EXISTS suppliers (
    uuid UUID NOT NULL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    address TEXT NOT NULL,
    city VARCHAR(50) NOT NULL,
    state VARCHAR(20) NOT NULL,
    postcode VARCHAR(20) NOT NULL,
    created_on TIMESTAMP NOT NULL,
    updated_on TIMESTAMP NULL
)
]]
        },
        {
            "orders", [[
CREATE TABLE IF NOT EXISTS orders (
    uuid UUID NOT NULL PRIMARY KEY,
    customer_uuid UUID NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_on TIMESTAMP NOT NULL,
    updated_on TIMESTAMP NULL
)
]]
        },
        {
            "orders_idx_status", [[
CREATE INDEX ix_status ON orders (status)
]]
        },
        {
            "orders_idx_customer_uuid", [[
CREATE INDEX ix_customer_uuid ON orders (customer_uuid)
]]
        },
        {
            "order_details", [[
CREATE TABLE IF NOT EXISTS order_details (
    order_uuid UUID NOT NULL,
    product_uuid UUID NOT NULL,
    quantity INT NOT NULL,
    price NUMERIC NOT NULL,
    fulfilling_supplier_uuid UUID NOT NULL,
    PRIMARY KEY (order_uuid, product_uuid)
)
]]
        },
        {
            "order_details_idx_product_fulfilling_supplier_uuid", [[
CREATE INDEX ix_product_fulfilling_supplier_uuid ON order_details (product_uuid, fulfilling_supplier_uuid)
]]
        },
        {
            "order_details_idx_fulfilling_supplier_uuid", [[
CREATE INDEX ix_fulfilling_supplier_uuid ON order_details (fulfilling_supplier_uuid)
]]
        }
    }
},
c = {
    mysql = {
        {
            "customers", [[
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
]]
        },
        {
            "products", [[
CREATE TABLE IF NOT EXISTS products (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    uuid VARCHAR(36) NOT NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT NULL,
    created_on DATETIME NOT NULL,
    updated_on DATETIME NULL,
    UNIQUE INDEX uix_uuid (uuid)
)
]]
        },
        {
            "product_price_history", [[
CREATE TABLE IF NOT EXISTS product_price_history (
    product_id INT NOT NULL,
    starting_on DATETIME NOT NULL,
    ending_on DATETIME NOT NULL,
    price DOUBLE NOT NULL,
    PRIMARY KEY (product_id, starting_on, ending_on)
)
]]
        },
        {
            "inventories", [[
CREATE TABLE IF NOT EXISTS inventories (
    product_id INT NOT NULL,
    supplier_id INT NOT NULL,
    total INT NOT NULL,
    PRIMARY KEY (product_id, supplier_id),
    INDEX ix_supplier_id (supplier_id)
)
]]
        },
        {
            "suppliers", [[
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
]]
        },
        {
            "orders", [[
CREATE TABLE IF NOT EXISTS orders (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    uuid VARCHAR(36) NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_on DATETIME NOT NULL,
    updated_on DATETIME NULL,
    INDEX ix_status (status),
    INDEX ix_customer_id (customer_id),
    UNIQUE INDEX uix_uuid (uuid)
)
]]
        },
        {
            "order_details", [[
CREATE TABLE IF NOT EXISTS order_details (
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    price DOUBLE NOT NULL,
    fulfilling_supplier_id INT NOT NULL,
    PRIMARY KEY (order_id, product_id),
    KEY ix_product_fulfilling_supplier_id (product_id, fulfilling_supplier_id),
    KEY ix_fulfilling_supplier_id (fulfilling_supplier_id)
)
]]
        }
    },
    pgsql = {
        {
            "customers", [[
CREATE TABLE IF NOT EXISTS customers (
    id SERIAL NOT NULL PRIMARY KEY,
    uuid UUID NOT NULL,
    name VARCHAR(200) NOT NULL,
    address TEXT NOT NULL,
    state VARCHAR(20) NOT NULL,
    city VARCHAR(50) NOT NULL,
    postcode VARCHAR(20) NOT NULL,
    created_on TIMESTAMP NOT NULL,
    updated_on TIMESTAMP NULL
)
]]
        },
        {
            "products", [[
CREATE TABLE IF NOT EXISTS products (
    id SERIAL NOT NULL PRIMARY KEY,
    uuid UUID NOT NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT NULL,
    created_on TIMESTAMP NOT NULL,
    updated_on TIMESTAMP NULL
)
]]
        },
        {
            "product_price_history", [[
CREATE TABLE IF NOT EXISTS product_price_history (
    product_id SERIAL NOT NULL,
    starting_on TIMESTAMP NOT NULL,
    ending_on TIMESTAMP NOT NULL,
    price NUMERIC NOT NULL,
    PRIMARY KEY (product_id, starting_on, ending_on)
)
]]
        },
        {
            "inventories", [[
CREATE TABLE IF NOT EXISTS inventories (
    product_id SERIAL NOT NULL,
    supplier_id SERIAL NOT NULL,
    total INT NOT NULL,
    PRIMARY KEY (product_id, supplier_id)
)
]]
        },
        {
            "inventories_idx", [[
CREATE INDEX ix_supplier_id ON inventories (supplier_id)
]]
        },
        {
            "supplers", [[
CREATE TABLE IF NOT EXISTS suppliers (
    id SERIAL NOT NULL PRIMARY KEY,
    uuid UUID NOT NULL,
    name VARCHAR(200) NOT NULL,
    address TEXT NOT NULL,
    city VARCHAR(50) NOT NULL,
    state VARCHAR(20) NOT NULL,
    postcode VARCHAR(20) NOT NULL,
    created_on TIMESTAMP NOT NULL,
    updated_on TIMESTAMP NULL
)
]]
        },
        {
            "orders", [[
CREATE TABLE IF NOT EXISTS orders (
    id SERIAL NOT NULL PRIMARY KEY,
    uuid UUID NOT NULL,
    customer_id SERIAL NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_on TIMESTAMP NOT NULL,
    updated_on TIMESTAMP NULL
)
]]
        },
        {
            "orders_idx_status", [[
CREATE INDEX ix_status ON orders (status)
]]
        },
        {
            "orders_idx_customer_id", [[
CREATE INDEX ix_customer_id ON orders (customer_id)
]]
        },
        {
            "order_details", [[
CREATE TABLE IF NOT EXISTS order_details (
    order_id SERIAL NOT NULL,
    product_id SERIAL NOT NULL,
    quantity INT NOT NULL,
    price NUMERIC NOT NULL,
    fulfilling_supplier_id SERIAL NOT NULL,
    PRIMARY KEY (order_id, product_id)
)
]]
        },
        {
            "order_details_idx_product_fulfilling_supplier_id", [[
CREATE INDEX ix_product_fulfilling_supplier_id ON order_details (product_id, fulfilling_supplier_id)
]]
        },
        {
            "order_details_idx_fulfilling_supplier_id", [[
CREATE INDEX ix_fulfilling_supplier_id ON order_details (fulfilling_supplier_id)
]]
        }
    }
}

}  -- end _schemas table

_insert_queries = {
    a = {
        customers = "INSERT INTO customers (name, address, city, state, postcode, created_on, updated_on) VALUES",
        customers_values = "('%s', '%s', '%s', '%s', '%s', NOW(), NOW())",
        products = "INSERT INTO products (name, description, created_on, updated_on) VALUES",
        products_values = "('%s', '%s', NOW(), NOW())",
        product_price_history = "INSERT INTO product_price_history (product_id, starting_on, ending_on, price) VALUES",
        product_price_history_values = "(%d, %s, %s, %0.2f)",
        suppliers = "INSERT INTO suppliers (name, address, city, state, postcode, created_on, updated_on) VALUES",
        suppliers_values = "('%s', '%s', '%s', '%s', '%s', NOW(), NOW())",
        inventories = "INSERT INTO inventories (product_id, supplier_id, total) VALUES",
        inventories_values = "(%d, %d, %d)",
    },
    b = {
        customers = "INSERT INTO customers (uuid, name, address, city, state, postcode, created_on, updated_on) VALUES",
        customers_values = "('%s', '%s', '%s', '%s', '%s', '%s', NOW(), NOW())",
        products = "INSERT INTO products (uuid, name, description, created_on, updated_on) VALUES",
        products_values = "('%s', '%s', '%s', NOW(), NOW())",
        product_price_history = "INSERT INTO product_price_history (product_uuid, starting_on, ending_on, price) VALUES",
        product_price_history_values = "('%s', %s, %s, %0.2f)",
        suppliers = "INSERT INTO suppliers (uuid, name, address, city, state, postcode, created_on, updated_on) VALUES",
        suppliers_values = "('%s', '%s', '%s', '%s', '%s', '%s', NOW(), NOW())",
        inventories = "INSERT INTO inventories (product_uuid, supplier_uuid, total) VALUES",
        inventories_values = "('%s', '%s', %d)",
    },
    c = {
        customers = "INSERT INTO customers (uuid, name, address, city, state, postcode, created_on, updated_on) VALUES",
        customers_values = "('%s', '%s', '%s', '%s', '%s', '%s', NOW(), NOW())",
        products = "INSERT INTO products (uuid, name, description, created_on, updated_on) VALUES",
        products_values = "('%s', '%s', '%s', NOW(), NOW())",
        product_price_history = "INSERT INTO product_price_history (product_id, starting_on, ending_on, price) VALUES",
        product_price_history_values = "(%d, %s, %s, %0.2f)",
        suppliers = "INSERT INTO suppliers (uuid, name, address, city, state, postcode, created_on, updated_on) VALUES",
        suppliers_values = "('%s', '%s', '%s', '%s', '%s', '%s', NOW(), NOW())",
        inventories = "INSERT INTO inventories (product_id, supplier_id, total) VALUES",
        inventories_values = "(%d, %d, %d)",
    }
}

statements = {
mysql = {
    a = {
        begin = {
            sql = "BEGIN"
        },
        commit = {
            sql = "COMMIT"
        },
        insert_order = {
            sql = [[
INSERT INTO orders (customer_id, status, created_on, updated_on)
VALUES (?, ?, NOW(), NOW())
]],
            binds = {
                sysbench.sql.type.INT,
                {sysbench.sql.type.VARCHAR, 20}
            }
        },
        insert_order_detail = {
            sql = [[
INSERT INTO order_details (order_id, product_id, fulfilling_supplier_id, quantity, price)
VALUES (?, ?, ?, ?, ?)
]],
            binds = {
                sysbench.sql.type.INT,
                sysbench.sql.type.INT,
                sysbench.sql.type.INT,
                sysbench.sql.type.INT,
                sysbench.sql.type.DOUBLE,
            }
        },
        select_orders_by_customer = {
            sql = [[
SELECT o.id, o.created_on, o.status, COUNT(*) AS num_items, SUM(od.quantity * od.price) AS total_amount
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
]]
        },
        select_order_counts_by_status = {
            sql = [[
SELECT o.status, COUNT(*) AS num_orders
FROM orders AS o
GROUP BY o.status
]]
        }
    },
    b = {
        begin = {
            sql = "BEGIN"
        },
        commit = {
            sql = "COMMIT"
        },
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
INSERT INTO order_details (order_uuid, product_uuid, fulfilling_supplier_uuid, quantity, price)
VALUES (?, ?, ?, ?, ?)
]],
            binds = {
                {sysbench.sql.type.CHAR, 36},
                {sysbench.sql.type.CHAR, 36},
                {sysbench.sql.type.CHAR, 36},
                sysbench.sql.type.INT,
                sysbench.sql.type.DOUBLE,
            }
        },
        select_orders_by_customer = {
            sql = [[
SELECT o.uuid, o.created_on, o.status, COUNT(*) AS num_items, SUM(od.quantity * od.price) AS total_amount
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
SELECT p.name, s.name, COUNT(DISTINCT o.uuid) AS included_in_orders, SUM(od.quantity * od.price) AS total_purchased
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
        },
        select_order_counts_by_status = {
            sql = [[
SELECT o.status, COUNT(*) AS num_orders
FROM orders AS o
GROUP BY o.status
]]
        }
    },
    c = {
        begin = {
            sql = "BEGIN"
        },
        commit = {
            sql = "COMMIT"
        },
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
INSERT INTO order_details (order_id, product_id, fulfilling_supplier_id, quantity, price)
VALUES (?, ?, ?, ?, ?)
]],
            binds = {
                sysbench.sql.type.INT,
                sysbench.sql.type.INT,
                sysbench.sql.type.INT,
                sysbench.sql.type.INT,
                sysbench.sql.type.DOUBLE,
            }
        },
        select_orders_by_customer = {
            sql = [[
SELECT o.uuid, o.created_on, o.status, COUNT(*) AS num_items, SUM(od.quantity * od.price) AS total_amount
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
]]
        },
        select_order_counts_by_status = {
            sql = [[
SELECT o.status, COUNT(*) AS num_orders
FROM orders AS o
GROUP BY o.status
]]
        }
    }
},
pgsql = {
    a = {
        begin = {
            sql = "BEGIN"
        },
        commit = {
            sql = "COMMIT"
        },
        insert_order = {
            sql = [[
INSERT INTO orders (customer_id, status, created_on, updated_on)
VALUES (?, ?, NOW(), NOW())
]],
            binds = {
                sysbench.sql.type.INT,
                {sysbench.sql.type.VARCHAR, 20}
            }
        },
        insert_order_detail = {
            sql = [[
INSERT INTO order_details (order_id, product_id, fulfilling_supplier_id, quantity, price)
VALUES (?, ?, ?, ?, ?)
]],
            binds = {
                sysbench.sql.type.INT,
                sysbench.sql.type.INT,
                sysbench.sql.type.INT,
                sysbench.sql.type.INT,
                sysbench.sql.type.DOUBLE,
            }
        },
        select_orders_by_customer = {
            sql = [[
SELECT o.id, o.created_on, o.status, COUNT(*) AS num_items, SUM(od.quantity * od.price) AS total_amount
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
]]
        },
        select_order_counts_by_status = {
            sql = [[
SELECT o.status, COUNT(*) AS num_orders
FROM orders AS o
GROUP BY o.status
]]
        }
    },
    b = {
        begin = {
            sql = "BEGIN"
        },
        commit = {
            sql = "COMMIT"
        },
        insert_order = {
            sql = [[
INSERT INTO orders (uuid, customer_uuid, status, created_on, updated_on)
VALUES (CAST(? AS UUID), CAST(? AS UUID), ?, NOW(), NOW())
]],
            binds = {
                {sysbench.sql.type.CHAR, 36},
                {sysbench.sql.type.CHAR, 36},
                {sysbench.sql.type.VARCHAR, 20}
            }
        },
        insert_order_detail = {
            sql = [[
INSERT INTO order_details (order_uuid, product_uuid, fulfilling_supplier_uuid, quantity, price)
VALUES (CAST(? AS UUID), CAST(? AS UUID), CAST(? AS UUID), ?, ?)
]],
            binds = {
                {sysbench.sql.type.CHAR, 36},
                {sysbench.sql.type.CHAR, 36},
                {sysbench.sql.type.CHAR, 36},
                sysbench.sql.type.INT,
                sysbench.sql.type.DOUBLE,
            }
        },
        select_orders_by_customer = {
            sql = [[
SELECT o.uuid, o.created_on, o.status, COUNT(*) AS num_items, SUM(od.quantity * od.price) AS total_amount
FROM orders AS o
JOIN order_details AS od
 ON o.uuid = od.order_uuid
WHERE o.customer_uuid = CAST(? AS UUID)
GROUP BY o.uuid
ORDER BY o.created_on DESC
]],
            binds = {
                {sysbench.sql.type.CHAR, 36},
            }
        },
        select_most_popular_product_suppliers = {
            sql = [[
SELECT p.name, s.name, COUNT(DISTINCT o.uuid) AS included_in_orders, SUM(od.quantity * od.price) AS total_purchased
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
        },
        select_order_counts_by_status = {
            sql = [[
SELECT o.status, COUNT(*) AS num_orders
FROM orders AS o
GROUP BY o.status
]]
        }
    },
    c = {
        begin = {
            sql = "BEGIN"
        },
        commit = {
            sql = "COMMIT"
        },
        insert_order = {
            sql = [[
INSERT INTO orders (uuid, customer_id, status, created_on, updated_on)
VALUES (CAST(? AS UUID), ?, ?, NOW(), NOW())
]],
            binds = {
                {sysbench.sql.type.CHAR, 36},
                sysbench.sql.type.INT,
                {sysbench.sql.type.VARCHAR, 20}
            }
        },
        insert_order_detail = {
            sql = [[
INSERT INTO order_details (order_id, product_id, fulfilling_supplier_id, quantity, price)
VALUES (?, ?, ?, ?, ?)
]],
            binds = {
                sysbench.sql.type.INT,
                sysbench.sql.type.INT,
                sysbench.sql.type.INT,
                sysbench.sql.type.INT,
                sysbench.sql.type.DOUBLE,
            }
        },
        select_orders_by_customer = {
            sql = [[
SELECT o.uuid, o.created_on, o.status, COUNT(*) AS num_items, SUM(od.quantity * od.price) AS total_amount
FROM orders AS o
JOIN order_details AS od
 ON o.id = od.order_id
JOIN customers AS c
 ON o.customer_id = c.id
WHERE c.uuid = CAST(? AS UUID)
GROUP BY o.id
ORDER BY o.created_on DESC
]],
            binds = {
                {sysbench.sql.type.CHAR, 36},
            }
        },
        select_most_popular_product_suppliers = {
            sql = [[
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
]]
        },
        select_order_counts_by_status = {
            sql = [[
SELECT o.status, COUNT(*) AS num_orders
FROM orders AS o
GROUP BY o.status
]]
        }
    }
}
}

_select_queries = {
    a = {
        current_price_for_product = [[
SELECT price FROM product_price_history
WHERE product_id = %d
AND NOW() BETWEEN starting_on AND ending_on
]],
        product_batch_limit_offset = [[
SELECT p.id FROM products AS p
ORDER BY p.id
LIMIT %d OFFSET %d
]],
        random_product_batch = [[
SELECT p.id FROM products AS p
LEFT JOIN inventories AS i
 ON p.id = i.product_id
WHERE i.product_id IS NULL
GROUP BY p.id
]],
        random_supplier_batch = [[
SELECT s.id FROM suppliers AS s
LEFT JOIN inventories AS i
 ON s.id = i.supplier_id
WHERE i.supplier_id IS NULL
GROUP BY s.id
]],
        random_customer_batch = [[
SELECT c.id FROM customers AS c
]],
        random_product_supplier_batch = [[
SELECT product_id, supplier_id
FROM inventories AS i
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
]]
    },
    b = {
        current_price_for_product = [[
SELECT price FROM product_price_history
WHERE product_uuid = '%s'
AND NOW() BETWEEN starting_on AND ending_on
]],
        product_batch_limit_offset = [[
SELECT p.uuid FROM products AS p
ORDER BY p.uuid
LIMIT %d OFFSET %d
]],
        random_product_batch = [[
SELECT p.uuid FROM products AS p
LEFT JOIN inventories AS i
 ON p.uuid = i.product_uuid
WHERE i.product_uuid IS NULL
GROUP BY p.uuid
]],
        random_supplier_batch = [[
SELECT s.uuid FROM suppliers AS s
LEFT JOIN inventories AS i
 ON s.uuid = i.supplier_uuid
WHERE i.supplier_uuid IS NULL
GROUP BY s.uuid
]],
        random_customer_batch = [[
SELECT c.uuid FROM customers AS c
]],
        random_product_supplier_batch = [[
SELECT product_uuid, supplier_uuid
FROM inventories AS i
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
]]
    },
    c = {
        current_price_for_product = [[
SELECT price FROM product_price_history
WHERE product_id = %d
AND NOW() BETWEEN starting_on AND ending_on
]],
        product_batch_limit_offset = [[
SELECT p.id FROM products AS p
ORDER BY p.id
LIMIT %d OFFSET %d
]],
        random_product_batch = [[
SELECT p.id FROM products AS p
LEFT JOIN inventories AS i
 ON p.id = i.product_id
WHERE i.product_id IS NULL
GROUP BY p.id
]],
        random_supplier_batch = [[
SELECT s.id FROM suppliers AS s
LEFT JOIN inventories AS i
 ON s.id = i.supplier_id
WHERE i.supplier_id IS NULL
GROUP BY s.id
]],
        random_customer_batch = [[
SELECT c.uuid FROM customers AS c
]],
        random_product_supplier_batch = [[
SELECT product_id, supplier_id
FROM inventories AS i
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
]],
        customer_internal_from_external = [[
SELECT c.id
FROM customers AS c
WHERE c.uuid = '%s'
]]
    }
}

function _rand_fn_name()
    if drv_name == 'mysql' then
        return 'RAND()'
    else
        return 'RANDOM()'
    end
end

function _last_insert_id()
    local _id
    if drv_name == 'mysql' then
        _id = con:query_row("SELECT LAST_INSERT_ID()")
    else
        _id = con:query_row("SELECT LASTVAL()")
    end
    return tonumber(_id)
end

function init()
    drv = sysbench.sql.driver()
    drv_name = drv:name()
    schema_design = sysbench.opt.schema_design

    if drv_name ~= "mysql" and drv_name ~= "pgsql" then
        error("Unsupported database driver:" .. drv_name)
    end
end

function connect()
    con = drv:connect()
end

function _num_records_in_table(table_name)
    local num_recs = con:query_row("SELECT COUNT(*) FROM " .. table_name)
    return tonumber(num_recs)
end

function _create_schema()
    print("PREPARE: ensuring database schema")

    for x, schema_block in ipairs(_schema[schema_design][drv_name]) do
        local element = schema_block[1]
        local sql = schema_block[2]
        print("PREPARE: creating " .. element)
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
        local values
        if schema_design == 'a' then
            values = string.format(
                values_tpl,
                c_name, c_address, c_city, c_state, c_postcode
            )
        else
            local new_uuid = uuid.new()
            values = string.format(
                values_tpl,
                new_uuid, c_name, c_address, c_city, c_state, c_postcode
            )
        end
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
    local limit = 50
    query = query .. string.format([[
ORDER BY %s
LIMIT %d
]], _rand_fn_name(), limit)
    local rs = con:query(query)
    local customers = {}
    for i = 1, rs.nrows do
        row = rs:fetch_row()
        customer = row[1]
        if schema_design == "a" then
            customer = tonumber(customer)
        end
        table.insert(customers, customer)
    end
    return customers
end

-- Get a batch of product internal identifiers using a limit and offset
function _get_product_batch(limit, offset)
    local query = _select_queries[schema_design]['product_batch_limit_offset']
    query = string.format(query, limit, offset)
    local rs = con:query(query)
    local products = {}
    for i = 1, rs.nrows do
        row = rs:fetch_row()
        product = row[1]
        if schema_design ~= "b" then
            product = tonumber(product)
        end
        table.insert(products, product)
    end
    return products
end

-- Get the current price for a product
function _get_current_price_for_product(product)
    local query = _select_queries[schema_design]['current_price_for_product']
    query = string.format(query, product)
    local price = con:query_row(query)
    return tonumber(price)
end

-- Get a batch of random product and supplier identifier pairs. Used when
-- creating a bunch of order details for customers during the prepare stage
function _get_random_product_supplier_batch()
    local query = _select_queries[schema_design]['random_product_supplier_batch']
    local limit = 200
    query = query .. string.format([[
ORDER BY %s
LIMIT %d
]], _rand_fn_name(), limit)
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
    stmt_tbl = statements[drv_name][schema_design][stmt_name]
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
    statements[drv_name][schema_design][stmt_name].statement = stmt
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
                -- For schema design "c", the tradeoff is we need to do a secondary key
                -- lookup on the external customer UUID to get the internal customer ID
                customer_id = customer
                if schema_design == "c" then
                    customer_id = get_customer_internal_from_external(customer)
                end
                order_stmt_params[1]:set(order_id)
                order_stmt_params[2]:set(customer_id)
                order_stmt_params[3]:set(status)
            end
            created_orders = created_orders + 1
            num_needed = num_needed - 1
            order_stmt:execute()

            if schema_design ~= "b" then
                order_id = _last_insert_id()
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
                    price = _get_current_price_for_product(product)
                    table.insert(products_in_order, product)
                    order_detail_stmt_params[1]:set(order_id)
                    order_detail_stmt_params[2]:set(product)
                    order_detail_stmt_params[3]:set(supplier)
                    order_detail_stmt_params[4]:set(amount)
                    order_detail_stmt_params[5]:set(price)
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

    _populate_product_prices()
end

function _populate_products(num_needed)
    local query = _insert_queries[schema_design]['products']
    local values_tpl = _insert_queries[schema_design]['products_values']

    con:bulk_insert_init(query)
    for i = 1, num_needed do
        local c_name = sysbench.rand.string(name_tpl)
        local c_description = sysbench.rand.string(description_tpl)
        local values
        if schema_design == 'a' then
            values = string.format(
                values_tpl, c_name, c_description
            )
        else
            local new_uuid = uuid.new()
            values = string.format(
                values_tpl, new_uuid, c_name, c_description
            )
        end
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
        local values
        if schema_design == 'a' then
            values = string.format(
                values_tpl,
                c_name, c_address, c_city, c_state, c_postcode
            )
        else
            local new_uuid = uuid.new()
            values = string.format(
                values_tpl,
                new_uuid, c_name, c_address, c_city, c_state, c_postcode
            )
        end
        con:bulk_insert_next(values)
    end
    con:bulk_insert_done()
    print(string.format("PREPARE: created %d supplier records.", num_needed))
end

function _populate_product_prices()
    local query = _insert_queries[schema_design]['product_price_history']
    local values_tpl = _insert_queries[schema_design]['product_price_history_values']
    local num_products = _num_records_in_table('products')

    -- For batches of 1000 product, create between 1 and 10 price periods for
    -- each product
    local count_n = 0
    while count_n < num_products do
        local products = _get_product_batch(1000, count_n)
        con:bulk_insert_init(query)
        for idx, product in ipairs(products) do
            local num_periods = sysbench.rand.uniform(1, 10)
            local start_date = os.time() - 1000000
            for period_idx = 1, num_periods do
                local end_datestr
                if period_idx == num_periods then
                    -- Make the last time interval end 100 years from now...
                    end_date = os.time() + (100*365*24*60*60)
                else
                    end_date = start_date + sysbench.rand.uniform(100, 10000)
                end
                end_datestr = os.date("'%Y-%m-%d %H:%M:%S'", end_date)
                start_datestr = os.date("'%Y-%m-%d %H:%M:%S'", start_date)
                local price = sysbench.rand.uniform_double()
                local values = string.format(values_tpl, product, start_datestr, end_datestr, price)
                con:bulk_insert_next(values)
                count_n = count_n + 1
                start_date = end_date + 1
            end
        end
        con:bulk_insert_done()
    end
    print(string.format("PREPARE: created %d price records.", count_n))
end

-- Get a batch of random product identifiers that are not already in
-- inventories table. Note this isn't a quick operation doing ORDER BY
-- RANDOM(), but this is only done in the prepare step so we should be OK
function _get_random_product_batch()
    local query = _select_queries[schema_design]['random_product_batch']
    local limit = 50
    query = query .. string.format([[
ORDER BY %s
LIMIT %d
]], _rand_fn_name(), limit)
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
    local limit = 50
    query = query .. string.format([[
ORDER BY %s
LIMIT %d
]], _rand_fn_name(), limit)
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
    init()
    connect()
    _create_schema()
    _create_supply_side()
    _create_consumer_side()
end

-- Completely removes and re-creates the database/catalog being used for
-- testing
function cleanup()
    init()

    local schema_name = sysbench.opt.mysql_db
    if drv_name == 'pgsql' then
        schema_name = sysbench.opt.pgsql_db
    end

    print("CLEANUP: dropping and recreating schema " .. schema_name)

    if drv_name == 'mysql' then
        connect()
        con:query("DROP DATABASE IF EXISTS " .. schema_name)
        con:query("CREATE DATABASE " .. schema_name)
    else
        -- Not able to drop the database that is actively connected to in
        -- PostgreSQL, so here, we close the connection and hack the drop using
        -- the dropdb CLI tool
        os.execute("su - postgres -c 'dropdb --if-exists sbtest'")
        os.execute("su - postgres -c 'createdb sbtest -Osbtest'")
    end
end

-- Returns a batch of 100 random external customer IDs
function _get_customer_external_ids()
    local query = _select_queries[schema_design]['random_customer_batch']
    local limit = 100
    query = query .. string.format([[
ORDER BY %s
LIMIT %d
]], _rand_fn_name(), limit)
    local rs = con:query(query)
    local customers = {}
    for i = 1, rs.nrows do
        row = rs:fetch_row()
        table.insert(customers, row[1])
    end
    return customers
end

function thread_init()
    init()
    connect()
    -- uuid.new() isn't thread-safe -- it creates the same set of UUIDs in
    -- order for each thread -- so we trick it into creating a "new" UUID by
    -- creating a new fake MAC address per thread
    thread_mac = sysbench.rand.string('##:##:##:##:##:##')
    scenario = sysbench.opt.scenario
    customers = _get_customer_external_ids()
    scenario_stmts = _prepare_scenario(scenario)
end

function thread_done()
    for idx, stmt_tbl in ipairs(scenario_stmts) do
        stmt_tbl.statement:close()
    end
end

scenarios = {
    order_counts_by_status = {
        statements = {
            'select_order_counts_by_status'
        }
    },
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
            'begin',
            'insert_order',
            'insert_order_detail',
            'commit'
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
    query = query .. string.format([[
ORDER BY %s
LIMIT %d
]], _rand_fn_name(), num_products)
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
    local begin = scenario_stmts[1]
    local ins_order = scenario_stmts[2]
    local ins_order_det = scenario_stmts[3]
    local commit = scenario_stmts[4]

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

    begin.statement:execute()
    ins_order.statement:execute()

    if schema_design ~= "b" then
        order_id = _last_insert_id()
    end

    for idx, product in ipairs(products) do
        local amount = sysbench.rand.uniform(1, 100)
        local supplier = get_fulfiller_for_product(product)
        local price = _get_current_price_for_product(product)
        ins_order_det.params[1]:set(order_id)
        ins_order_det.params[2]:set(product)
        ins_order_det.params[3]:set(supplier)
        ins_order_det.params[4]:set(amount)
        ins_order_det.params[5]:set(price)
        ins_order_det.statement:execute()
    end
    commit.statement:execute()
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

function execute_order_counts_by_status()
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
    elseif scenario == 'order_counts_by_status' then
        execute_order_counts_by_status()
    end
end
