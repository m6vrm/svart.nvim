local M = {}

function M.keys(iter)
    local keys = {}

    for key, _ in iter() do
        table.insert(keys, key)
    end

    return keys
end

function M.values(iter)
    local values = {}

    for _, value in iter() do
        table.insert(values, value)
    end

    return values
end

function M.string_prefix(string, prefix)
    return string:sub(1, prefix:len()) == prefix
end

function M.make_bimap(keys_to_values, values_to_keys)
    local keys_to_values = keys_to_values or {}
    local value_to_string = function(value) return vim.inspect(value) end

    local index_values = function(keys_to_values)
        local values_to_keys = {}

        for key, value in pairs(keys_to_values) do
            values_to_keys[value_to_string(value)] = key
        end

        return values_to_keys
    end

    local values_to_keys = values_to_keys or index_values(keys_to_values)

    return {
        pairs = function()
            return pairs(keys_to_values)
        end,
        get_keys = function()
            return M.values(function() return pairs(values_to_keys) end)
        end,
        get_values = function()
            return M.values(function() return pairs(keys_to_values) end)
        end,
        drop_first = function()
            local key, value = next(keys_to_values)

            if key == nil then
                return nil
            end

            keys_to_values[key] = nil
            values_to_keys[value_to_string(value)] = nil
            return value
        end,
        set = function(key, value)
            if key == nil or value == nil then return end
            keys_to_values[key] = value
            values_to_keys[value_to_string(value)] = key
        end,
        remove_value = function(value)
            if value == nil then return end
            local key = values_to_keys[value_to_string(value)]
            if key == nil then return end
            keys_to_values[key] = nil
            values_to_keys[value_to_string(value)] = nil
        end,
        remove_key = function(key)
            if key == nil then return end
            local value = keys_to_values[key]
            if value == nil then return end
            values_to_keys[value_to_string(value)] = nil
            keys_to_values[key] = nil
        end,
        get_value = function(key)
            return keys_to_values[key]
        end,
        get_key = function(value)
            if value == nil then return nil end
            return values_to_keys[value_to_string(value)]
        end,
        copy = function()
            return M.make_bimap(vim.deepcopy(keys_to_values), vim.deepcopy(values_to_keys))
        end,
    }
end

return M
