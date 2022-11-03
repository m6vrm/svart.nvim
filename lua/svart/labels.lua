local config = require("svart.config")
local utils = require("svart.utils")
local buf = require("svart.buf")

local function generate_labels(atoms, min_count, max_len)
    local labels = utils.make_bimap({ unpack(atoms) })

    while true do
        local tail = {}

        for _, label in labels.pairs() do
            for _, atom in ipairs(atoms) do
                if #label + #atom <= max_len and atom ~= label:sub(#atom) then
                    table.insert(tail, atom .. label)
                end
            end
        end

        if next(tail) == nil then
            break
        end

        for _, label in ipairs(tail) do
            local prefix = label:sub(1, -2)
            labels.remove_value(prefix)
            labels.append(label)

            if labels.count() >= min_count then
                return labels
            end
        end
    end

    return labels
end

-- sort by the distance to the middle line
local function sort_matches(matches, bounds)
    local middle_line = math.floor(bounds.top + (bounds.bottom - bounds.top) / 2)

    table.sort(matches, function(match1, match2)
        local dist1 = math.abs(match1[1] - middle_line)
        local dist2 = math.abs(match2[1] - middle_line)

        if dist1 ~= dist2 then return dist1 < dist2 end
        if match1[1] ~= match2[1] then return match1[1] < match2[1] end
        return match1[2] < match2[2]
    end)
end

-- remove labels that may conflict with next possible query char
local function discard_conflicting_labels(labels, matches, query, prev_labeled_matches, buf)
    for _, match in ipairs(matches) do
        local line_nr, col = unpack(match)
        local line = buf.line_at(line_nr)
        local next_char = line:sub(col + #query, col + #query):lower()

        -- todo: refactor
        for _, label in labels.pairs() do
            if label:sub(1, 1) == next_char then
                labels.remove_value(label)
                prev_labeled_matches.remove_key(label)
            end
        end

        for label, _ in prev_labeled_matches.pairs() do
            if label:sub(1, 1) == next_char then
                labels.remove_value(label)
                prev_labeled_matches.remove_key(label)
            end
        end
    end
end

local function label_matches(matches, labels, prev_labeled_matches, labeled_matches)
    -- try to use labels from the previous matches
    for _, match in ipairs(matches) do
        local label = prev_labeled_matches.key(match)

        if label ~= nil then
            labels.remove_value(label)
            labeled_matches.set(label, match)
        end
    end

    -- then add new labels to remaining matches
    for _, match in ipairs(matches) do
        local prev_label = labeled_matches.key(match)

        if prev_label == nil then
            local label = labels.drop_first()

            if label ~= nil then
                labeled_matches.set(label, match)
            end
        end
    end
end

-- remove matches with irrelevant labels
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

            if #query < config.label_min_query_len then
                return history[query]
            end

            local matches = { unpack(matches) }
            local labels = generate_labels(config.label_atoms, #matches * 2, config.label_max_len)

            local prev_query = query:sub(1, -2)
            local prev_labeled_matches = history[prev_query] ~= nil
                and history[prev_query].copy()
                or utils.make_bimap()

            local labeled_matches = history[query]

            sort_matches(matches, buf.visible_bounds())
            discard_conflicting_labels(labels, matches, query, prev_labeled_matches, buf)
            label_matches(matches, labels, prev_labeled_matches, labeled_matches)

            if config.label_hide_irrelevant then
                -- todo
               -- discard_irrelevant_labeled_matches(labeled_matches, label)
            end

            return labeled_matches
        end,
    }
end

local function test()
    local tests = require("svart.tests")

    -- generate_labels
    do
        local atoms = { "a", "b", "c", "d" }
        local labels = generate_labels(atoms, 1, 1)
        tests.assert_eq(labels.values(), { "a", "b", "c", "d" })

        labels = generate_labels(atoms, 6, 1)
        tests.assert_eq(labels.values(), { "a", "b", "c", "d" })
    end

    -- sort_matches
    do
        local bounds = { top = 1, bottom = 9 }
        local matches = { { 2, 1 }, { 5, 1 }, { 7, 1 } }
        sort_matches(matches, bounds)
        tests.assert_eq(matches[1][1], 5)
        tests.assert_eq(matches[2][1], 7)
        tests.assert_eq(matches[3][1], 2)

        bounds = { top = 1, bottom = 1 }
        matches = { { 1, 1 }, { 1, 2 } }
        sort_matches(matches, bounds)
        tests.assert_eq(matches[1][2], 1)
        tests.assert_eq(matches[2][2], 2)
    end

    -- discard_conflicting_labels
    do
        local labels = utils.make_bimap({ "a", "e", "in" })
        local matches = { { 1, 1 }, { 1, 6 } }
        local query = "l"
        local prev_labeled_matches = utils.make_bimap({ e = { 1, 1 } })
        local buf = { line_at = function(line_nr) return "test line" end }
        discard_conflicting_labels(labels, matches, query, prev_labeled_matches, buf)
        tests.assert_eq(labels.key("e"), nil)
        tests.assert_eq(labels.key("in"), nil)
        tests.assert_eq(prev_labeled_matches.key({ 1, 1 }), nil)
    end

    -- label_matches
    do
        local matches = { { 2, 1 }, { 5, 1 }, { 7, 1 }, { 8, 1 }, { 9, 1 } }
        local labels = utils.make_bimap({ "a", "b", "c" })
        local prev_labeled_matches = utils.make_bimap({ x = { 2, 1 }, c = { 9, 1 } })
        local labeled_matches = utils.make_bimap()
        label_matches(matches, labels, prev_labeled_matches, labeled_matches)
        tests.assert_eq(labeled_matches.value("x")[1], 2)
        tests.assert_eq(labeled_matches.value("a")[1], 5)
        tests.assert_eq(labeled_matches.value("b")[1], 7)
        tests.assert_eq(labeled_matches.value("c")[1], 9)
        tests.assert_eq(labeled_matches.key({ 8, 1 }), nil)
    end

    -- discard_irrelevant_labeled_matches
    do
        local labeled_matches = utils.make_bimap({ aa = { 2, 1 }, ba = { 3, 1 }, bb = { 1, 1 } })
        local current_label = "b"
        discard_irrelevant_labeled_matches(labeled_matches, current_label)
        tests.assert_eq(labeled_matches.value("aa"), nil)
        tests.assert_eq(labeled_matches.value("ba")[1], 3)
        tests.assert_eq(labeled_matches.value("bb")[1], 1)
    end
end

return {
    make_marker = make_marker,
    test = test,
}
