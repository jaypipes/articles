if sysbench.cmdline.command == nil then
    error("Command is required. Supported commands: prepare, warmup, run, " ..
          "cleanup, help")
end

sysbench.cmdline.options = {
    application =
        {"Application to benchmark ('brick-and-mortar', 'employee-directory')", "brick-and-mortar"},
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

function validate()
    local drv = sysbench.sql.driver()
    local con = drv:connect()
    local drv_name = drv:name()

    if drv_name ~= "mysql" and drv_name ~= "postgresql" then
        error("Unsupported database driver:" .. drv_name)
    end
end

function script_path()
    local str = debug.getinfo(2, "S").source:sub(2)
    return str:match("(.*/)")
end

-- Creates the schema tables and populates the tables with data up to the
-- required record counts taken from the command-line options
function prepare()
    validate()

    local drv = sysbench.sql.driver()
    local con = drv:connect()
    local drv_name = drv:name()

    local schema_path = script_path() .. 'schemas/' .. sysbench.opt.application .. '/' .. sysbench.opt.schema_design .. '.' .. drv_name
    local schema_file = assert(io.open(schema_path))
    local schema_sql = schema_file:read("*all")
end
