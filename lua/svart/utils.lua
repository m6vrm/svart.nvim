local M = {}

function M.table_keys(table_)
    local keys = {}

    for key, _ in pairs(table_) do
        table.insert(keys, key)
    end

    return keys
end

function M.table_values(table_)
    local values = {}

    for _, value in pairs(table_) do
        table.insert(values, value)
    end

    return values
end

function M.table_flip(table_)
    local flipped = {}

    for _, value in pairs(table_) do
        flipped[value] = true
    end

    return flipped
end

function M.string_prefix(string, prefix)
    assert(prefix ~= "")
    return string:sub(1, #prefix) == prefix
end

-- bidirectional map (https://www.boost.org/doc/libs/1_79_0/libs/bimap/doc/html/index.html)
function M.make_bimap(keys_to_values, values_to_keys, count, value_to_string)
    local value_to_string = value_to_string or function(value) return vim.inspect(value) end

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

    local this = {}

    this.dump = function()
        return vim.inspect(keys_to_values)
    end

    this.copy = function()
        return M.make_bimap(
            vim.deepcopy(keys_to_values),
            vim.deepcopy(values_to_keys),
            count,
            value_to_string
        )
    end

    this.count = function()
        return count
    end

    this.pairs = function()
        return pairs(keys_to_values)
    end

    this.keys = function()
        return M.table_values(values_to_keys)
    end

    this.values = function()
        return M.table_values(keys_to_values)
    end

    this.value = function(key)
        assert(key ~= nil)
        return keys_to_values[key]
    end

    this.key = function(value)
        assert(value ~= nil)
        return values_to_keys[value_to_string(value)]
    end

    this.has_value = function(value)
        assert(value ~= nil)
        return values_to_keys[value_to_string(value)] ~= nil
    end

    this.has_key = function(key)
        assert(key ~= nil)
        return keys_to_values[key] ~= nil
    end

    this.remove_value = function(value)
        assert(value ~= nil)
        local key = values_to_keys[value_to_string(value)]
        if key == nil then return end
        keys_to_values[key] = nil
        values_to_keys[value_to_string(value)] = nil
        count = count - 1
        assert(count >= 0)
    end

    this.remove_key = function(key)
        assert(key ~= nil)
        local value = keys_to_values[key]
        if value == nil then return end
        values_to_keys[value_to_string(value)] = nil
        keys_to_values[key] = nil
        count = count - 1
        assert(count >= 0)
    end

    this.set = function(key, value)
        assert(key ~= nil)
        assert(value ~= nil)
        this.remove_key(key)
        this.remove_value(value)
        keys_to_values[key] = value
        values_to_keys[value_to_string(value)] = key
        count = count + 1
    end

    this.replace = function(old_key, new_key, value)
        assert(old_key ~= nil)
        assert(new_key ~= nil)
        assert(value ~= nil)
        this.remove_key(old_key)
        this.set(new_key, value)
    end

    this.append = function(value)
        assert(value ~= nil)
        this.remove_value(value)
        table.insert(keys_to_values, value)
        values_to_keys[value_to_string(value)] = #keys_to_values
        count = count + 1
    end

    this.first = function()
        local _, value = next(keys_to_values)
        return value
    end

    this.drop_first = function()
        local key, value = next(keys_to_values)
        if key == nil then return nil end
        keys_to_values[key] = nil
        values_to_keys[value_to_string(value)] = nil
        count = count - 1
        assert(count >= 0)
        return value
    end

    return this
end

function M.test(tests)
    -- table_keys
    do
        -- map
        local keys = M.table_keys({ k1 = 1, k2 = 2, k3 = 3 })
        tests.assert_eq(#keys, 3)

        -- array
        keys = M.table_keys({ "v1", "v2", "v3" })
        tests.assert_eq(keys, { 1, 2, 3 })
    end

    -- table_values
    do
        -- map
        local values = M.table_values({ k1 = 1, k2 = 2, k3 = 3 })
        tests.assert_eq(#values, 3)

        -- array
        values = M.table_values({ "v1", "v2", "v3" })
        tests.assert_eq(values, { "v1", "v2", "v3" })
    end

    -- table_flip
    do
        local flipped = M.table_flip({ v1, v2, v3, v3 })
        tests.assert_eq(flipped.v1)
        tests.assert_eq(flipped.v2)
        tests.assert_eq(flipped.v3)
    end

    -- string_prefix
    do
        -- prefix equal to string
        assert(M.string_prefix("hello", "hello"))

        -- prefix of the string
        assert(M.string_prefix("hello", "hell"))

        -- empty string
        assert(not M.string_prefix("", "hello"))

        -- suffix of the string
        assert(not M.string_prefix("hello", "ello"))
    end

    -- make_bimap
    do
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
        bimap.append("v1")
        bimap.append("v2")
        bimap.append("v2") -- duplicates aren't allowed
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

        -- replace key (set new value to the existing key)
        bimap.set("k1", "v3")
        tests.assert_eq(bimap.count(), 2)
        tests.assert_eq(bimap.value("k1"), "v3")
        tests.assert_eq(bimap.key("v3"), "k1")
        tests.assert_eq(bimap.key("v1"), nil) -- old value is removed

        -- replace value (set existing value to the new key)
        bimap.set("k3", "v3")
        tests.assert_eq(bimap.count(), 2)
        tests.assert_eq(bimap.value("k1"), nil) -- old key is removed since
                                                -- duplicates aren't allowed
        tests.assert_eq(bimap.key("v3"), "k3")

        -- copy now, then change original,
        -- then test that copy not changed
        local bimap_copy = bimap.copy()

        -- remove key
        bimap.remove_key("k3")
        tests.assert_eq(bimap.count(), 1)
        tests.assert_eq(bimap.value("k3"), nil)

        -- remove value
        bimap.remove_value("v2")
        tests.assert_eq(bimap.count(), 0)
        tests.assert_eq(bimap.key("v2"), nil)

        -- test copy not changed
        tests.assert_eq(bimap_copy.count(), 2)
        tests.assert_eq(bimap_copy.value("k3"), "v3")
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

        -- custom `value_to_string`
        local value_to_string = function(value) return vim.inspect({ value[1] }) end
        local bimap = M.make_bimap(nil, nil, nil, value_to_string)

        bimap.append({ 1, 1 })
        bimap.append({ 1, 2 })
        tests.assert_eq(bimap.count(), 1)
        assert(bimap.has_value({ 1, 2 }))
        assert(bimap.has_value({ 1, 1 })) -- true since `has_value` internally uses the `value_to_string`
    end
end

return M
