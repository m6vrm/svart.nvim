function table.key(table, element)
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

function table.keys(table_)
    local keys = {}

    for key, _ in pairs(table_) do
        table.insert(keys, key)
    end

    return keys
end
