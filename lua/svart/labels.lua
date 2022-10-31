local buf = require("svart.buf")

local function escape_char(char)
    return char:lower():gsub("%p", "%%%1")
end

local function drop_char(string, char)
    local pattern = escape_char(char)
    return string:gsub(pattern, "")
end

local function find_char(string, char)
    if char == nil or char == "" then
        return false
    end

    local pattern = escape_char(char)
    return string:find(pattern)
end

local function is_new_query(query, last_query)
    return query ~= last_query
        and last_query:sub(1, query:len()) ~= query
        and query:sub(1, last_query:len()) ~= last_query
end

local function label()
    local last_query = ""
    local labels_index = {}

    return {
        matches = function (matches, query)
            if is_new_query(query, last_query) then
                labels_index = {}
            end

            last_query = query

            local query_len = query:len()
            local available_labels = "jfkdlsahgnuvrbytmiceoxwpqz[];'\\,./1234567890-="

            -- discard labels that collide with next char in any match
            for i, match in ipairs(matches) do
                local next_char = buf.get_char_at_pos({ match[1], match[2] + query_len })
                available_labels = drop_char(available_labels, next_char)
            end

            local labeled_matches = {}

            -- get label from cached index or from available labels pool
            for i, match in ipairs(matches) do
                local index_key = table.concat(match, ":")
                local label = labels_index[index_key]

                if not find_char(available_labels, label) then
                    label = available_labels:sub(1, 1)
                    labels_index[index_key] = label
                end

                available_labels = drop_char(available_labels, label)
                labeled_matches[label] = match
            end

            return labeled_matches
        end,
    }
end

return {
    label = label,
}
