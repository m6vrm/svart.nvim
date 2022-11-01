local M = {}

function M.table_key(table, element)
    if element == nil or element == "" then
        return nil
    end

    for key, value in pairs(table) do
        if value == element then
            return key
        end
    end

    return nil
end

function M.table_keys(table_)
    local keys = {}

    for key, _ in pairs(table_) do
        table.insert(keys, key)
    end

    return keys
end

function M.string_prefix(string, prefix)
    return string == prefix
        or string:sub(1, prefix:len()) == prefix
end

return M
