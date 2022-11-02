local config = require("svart.config")
local utils = require("svart.utils")
local buf = require("svart.buf")

local function generate_labels(min_count, max_len)
    return utils.make_bimap({ unpack(config.labels) })
end

local function sort_matches(matches)
    local visible_bounds = buf.get_visible_bounds()
    local middle_line = math.floor(visible_bounds.top + (visible_bounds.bottom - visible_bounds.top) / 2)

    table.sort(matches, function(match1, match2)
        local dist1 = math.abs(match1[1] - middle_line)
        local dist2 = math.abs(match2[1] - middle_line)

        if dist1 ~= dist2 then return dist1 < dist2 end
        if match1[1] ~= match2[1] then return match1[1] < match2[1] end
        return match1[2] < match2[2]
    end)
end

local function discard_conflicting_labels(labels, matches, query, prev_labeled_matches)
    local query_len = query:len()

    for _, match in ipairs(matches) do
        local line_nr, col = unpack(match)
        local line = buf.get_line(line_nr)
        local next_char = line:sub(col + query_len, col + query_len):lower()

        for _, label in labels.pairs() do
            if label:sub(1, 1) == next_char then
                labels.remove_value(label)
                prev_labeled_matches.remove_key(label)
            end
        end
    end
end

local function label_matches(matches, labels, prev_labeled_matches, labeled_matches, query)
    for _, match in pairs(matches) do
        local label = prev_labeled_matches.get_key(match)
        labels.remove_value(label)
        labeled_matches.set(label, match)
    end

    for _, match in pairs(matches) do
        if labeled_matches.get_key(match) == nil then
            local label = labels.drop_first()
            labeled_matches.set(label, match)
        end
    end
end

local function discard_irrelevant_labeled_matches(labeled_matches, current_label)
    for label, _ in labeled_matches.pairs() do
        if not utils.string_prefix(label, current_label) then
            labeled_matches.remove_key(label)
        end
    end
end

local function make_marker()
    local history = {}

    return {
        label_matches = function(matches, query, label)
            if query == "" then
                history = {}
            end

            if history[query] ~= nil then
                return history[query]
            end

            history[query] = utils.make_bimap()

            if query:len() < config.label_min_query_len then
                return history[query]
            end

            local matches = { unpack(matches) }
            local labels = generate_labels(#matches, config.label_max_len)

            local prev_query = query:sub(1, -2)
            local prev_labeled_matches = history[prev_query] ~= nil
                and history[prev_query].copy()
                or utils.make_bimap()

            local labeled_matches = history[query]

            sort_matches(matches)
            discard_conflicting_labels(labels, matches, query, prev_labeled_matches)
            label_matches(matches, labels, prev_labeled_matches, labeled_matches, query)

            if config.label_hide_irrelevant then
                discard_irrelevant_labeled_matches(labeled_matches, label)
            end

            return labeled_matches
        end,
    }
end

return {
    make_marker = make_marker,
}
