if sysbench.cmdline.command == nil then
    error("Command is required. Supported commands: prepare, warmup, run, " ..
          "cleanup, help")
end

sysbench.cmdline.options = {
    schema_design =
        {"Schema design to benchmark", "a"},
    num_products =
        {"Number of products to create", 1000},
    num_customers =
        {"Number of customers to create", 10000},
    num_suppliers =
        {"Number of suppliers per product to create", 1},
    num_orders =
        {"Number of orders to create", 100000},
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
]]
    }
}

_insert_queries = {
    a = {
        customers = "INSERT INTO customers (id, name, address, city, state, postcode, created_on, updated_on) VALUES"
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

function _script_path()
    local str = debug.getinfo(2, "S").source:sub(2)
    return str:match("(.*/)")
end

function _num_records_in_table(table_name)
    local num_recs = con:query_row("SELECT COUNT(*) FROM " .. table_name)
    return tonumber(num_recs)
end

function _create_schema(schema_design)
    local schema_path = _script_path() .. 'schemas/brick-and-mortar/' .. schema_design .. '.' .. drv_name
    local schema_file = assert(io.open(schema_path))
    local schema_sql = schema_file:read("*all")
    schema_file:close()

    print("PREPARE: ensuring database schema")

    for tbl, sql in pairs(_schema[schema_design]) do
        print("PREPARE: creating table " .. tbl)
        con:query(sql)
    end
end

-- I'd like to do a random string of some range of length, but can't do that
-- with sysbench's internal rand.string
name_tpl = "########## ############################"
address_tpl = "################\n##############\n############"
city_tpl = "###########################"
state_tpl = "##############"
postcode_tpl = "######"

function _create_customers(schema_design)
    local num_records = _num_records_in_table('customers')
    local num_needed = sysbench.opt.num_customers - num_records

    print(string.format("PREPARE: found %d customer records. creating %d customer records.", num_records, num_needed))

    local query = _insert_queries[schema_design]['customers']

    con:bulk_insert_init(query)
    for i = 1, num_needed do
        local c_name = sysbench.rand.string(name_tpl)
        local c_address = sysbench.rand.string(address_tpl)
        local c_city = sysbench.rand.string(city_tpl)
        local c_city = sysbench.rand.string(state_tpl)
        local c_postcode = sysbench.rand.string(postcode_tpl)
        local values = string.format(
            "(NULL, '%s', '%s', '%s', '%s', '%s', NOW(), NOW())",
            c_name, c_address, c_city, c_state, c_postcode
        )
        con:bulk_insert_next(values)
    end
    con:bulk_insert_done()
end

-- Creates the schema tables and populates the tables with data up to the
-- required record counts taken from the command-line options
function prepare()
    local schema_design = sysbench.opt.schema_design
    _init()
    _create_schema(schema_design)
    _create_customers(schema_design)
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
