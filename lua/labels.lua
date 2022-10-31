local buf = require("buf")

function label_matches(matches, query)
    local labeled_matches = {}
    local query_len = query:len()

    local available_labels = "jfkdlsahgnuvrbytmiceoxwpqz[];'\\,./1234567890-="

    for i, match in ipairs(matches) do
        local next_char = buf.get_char_at_pos({ match[1], match[2] + query_len })
        local pattern = next_char:lower():gsub("%p", "%%%1")
        available_labels = available_labels:gsub(pattern, "")
    end

    for i, match in ipairs(matches) do
        if available_labels == "" then
            break
        end

        local label = available_labels:sub(1, 1)
        available_labels = available_labels:sub(2)
        labeled_matches[label] = match
    end

    return labeled_matches
end

return {
    label_matches = label_matches,
}
