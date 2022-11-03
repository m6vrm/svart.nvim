local M = {}

function M.keys(table_)
    local keys = {}

    for key, _ in pairs(table_) do
        table.insert(keys, key)
    end

    return keys
end

function M.values(table_)
    local values = {}

    for _, value in pairs(table_) do
        table.insert(values, value)
    end

    return values
end

function M.string_prefix(string, prefix)
    return string:sub(1, #prefix) == prefix
end

function M.make_bimap(keys_to_values, values_to_keys, count)
    local value_to_string = function(value) return vim.inspect(value) end

    local index_values = function(keys_to_values)
        local values_to_keys = {}
        for key, value in pairs(keys_to_values) do
            values_to_keys[value_to_string(value)] = key
        end
        return values_to_keys
    end

    local count_non_nil = function(keys_to_values)
        local count = 0
        for _, value in pairs(keys_to_values) do
            count = count + 1
        end
        return count
    end

    local keys_to_values = keys_to_values or {}
    local values_to_keys = values_to_keys or index_values(keys_to_values)
    local count = count or count_non_nil(keys_to_values)

    return {
        count = function()
            return count
        end,
        pairs = function()
            return pairs(keys_to_values)
        end,
        keys = function()
            return M.values(values_to_keys)
        end,
        values = function()
            return M.values(keys_to_values)
        end,
        append = function(value)
            assert(value ~= nil)
            table.insert(keys_to_values, value)
            values_to_keys[value_to_string(value)] = #keys_to_values
            count = count + 1
        end,
        first = function()
            local _, value = next(keys_to_values)
            return value
        end,
        drop_first = function()
            local key, value = next(keys_to_values)
            if key == nil then return nil end
            keys_to_values[key] = nil
            values_to_keys[value_to_string(value)] = nil
            count = count - 1
            assert(count >= 0)
            return value
        end,
        set = function(key, value)
            assert(key ~= nil)
            assert(value ~= nil)
            local old_value = keys_to_values[key]
            if old_value == nil then
                count = count + 1
            else
                values_to_keys[value_to_string(old_value)] = nil
            end
            keys_to_values[key] = value
            values_to_keys[value_to_string(value)] = key
        end,
        remove_value = function(value)
            assert(value ~= nil)
            local key = values_to_keys[value_to_string(value)]
            if key == nil then return end
            keys_to_values[key] = nil
            values_to_keys[value_to_string(value)] = nil
            count = count - 1
            assert(count >= 0)
        end,
        remove_key = function(key)
            assert(key ~= nil)
            local value = keys_to_values[key]
            if value == nil then return end
            values_to_keys[value_to_string(value)] = nil
            keys_to_values[key] = nil
            count = count - 1
            assert(count >= 0)
        end,
        value = function(key)
            return keys_to_values[key]
        end,
        key = function(value)
            assert(value ~= nil)
            return values_to_keys[value_to_string(value)]
        end,
        copy = function()
            return M.make_bimap(vim.deepcopy(keys_to_values), vim.deepcopy(values_to_keys), count)
        end,
    }
end

function M.test()
    local tests = require("svart.tests")

    -- keys
    local _ = (function()
        local keys = M.keys({ k1 = 1, k2 = 2, k3 = 3 })
        tests.assert_eq(#keys, 3)

        keys = M.keys({ "v1", "v2", "v3" })
        tests.assert_eq(keys, { 1, 2, 3 })
    end)()

    -- values
    local _ = (function()
        local values = M.values({ k1 = 1, k2 = 2, k3 = 3 })
        tests.assert_eq(#values, 3)

        values = M.values({ "v1", "v2", "v3" })
        tests.assert_eq(values, { "v1", "v2", "v3" })
    end)()

    -- string_prefix
    local _ = (function()
        assert(M.string_prefix("hello", "hello"))
        assert(M.string_prefix("hello", "hell"))
        assert(M.string_prefix("hello", ""))
        assert(not M.string_prefix("", "hello"))
        assert(not M.string_prefix("hello", "ello"))
    end)()

    -- make_bmap
    local _ = (function()
        -- empty
        local bimap = M.make_bimap()
        tests.assert_eq(bimap.count(), 0)
        tests.assert_eq(bimap.keys(), {})
        tests.assert_eq(bimap.values(), {})
        tests.assert_eq(bimap.first(), nil)
        tests.assert_eq(bimap.drop_first(), nil)
        tests.assert_eq(bimap.count(), 0)

        -- append
        bimap.append("v1")
        bimap.append("v2")
        tests.assert_eq(bimap.count(), 2)
        tests.assert_eq(bimap.first(), "v1")
        tests.assert_eq(bimap.drop_first(), "v1")
        tests.assert_eq(bimap.count(), 1)
        tests.assert_eq(bimap.values(), { "v2" })
        tests.assert_eq(bimap.drop_first(), "v2")
        tests.assert_eq(bimap.count(), 0)

        -- set
        bimap.set("k1", "v1")
        bimap.set("k2", "v2")
        tests.assert_eq(bimap.count(), 2)
        tests.assert_eq(bimap.value("k1"), "v1")
        tests.assert_eq(bimap.value("k2"), "v2")
        tests.assert_eq(bimap.key("v1"), "k1")
        tests.assert_eq(bimap.key("v2"), "k2")

        -- replace
        bimap.set("k1", "v3")
        tests.assert_eq(bimap.count(), 2)
        tests.assert_eq(bimap.value("k1"), "v3")
        tests.assert_eq(bimap.key("v3"), "k1")
        tests.assert_eq(bimap.key("v1"), nil)

        local bimap_copy = bimap.copy()

        -- remove key
        bimap.remove_key("k1")
        tests.assert_eq(bimap.count(), 1)
        tests.assert_eq(bimap.value("k1"), nil)

        -- remove value
        bimap.remove_value("v2")
        tests.assert_eq(bimap.count(), 0)
        tests.assert_eq(bimap.key("v2"), nil)

        -- copy
        tests.assert_eq(bimap_copy.count(), 2)
        tests.assert_eq(bimap_copy.value("k1"), "v3")
        tests.assert_eq(bimap_copy.value("k2"), "v2")

        -- init
        local bimap = M.make_bimap({ k1 = "v1", k2 = "v2" })
        tests.assert_eq(bimap.count(), 2)
        tests.assert_eq(bimap.value("k1"), "v1")
        tests.assert_eq(bimap.value("k2"), "v2")

        -- gaps
        local bimap = M.make_bimap({ nil, 1, 2, nil, 3 })
        tests.assert_eq(bimap.count(), 3)
        tests.assert_eq(bimap.values(), { 1, 2, 3 })
    end)()
end

return M
