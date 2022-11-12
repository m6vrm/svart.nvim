local utils = require("svart.utils")

local function make_matches_bimap()
    local match_to_string = function(match)
        local static_match = { win_id = match.win_id, line = match.line, col = match.col }
        return vim.inspect(static_match)
    end

    return utils.make_bimap(nil, nil, nil, match_to_string)
end

local function make_labels_pool(atoms, min_count, max_len)
    local generated = false
    local labels = utils.make_bimap()
    local discarded = {}

    local available = function(label)
        -- `bla` will discard following: b, bl, bla, bla*
        -- `a` will discard following: a, a*
        for discarded_label, _ in pairs(discarded) do
            if utils.string_prefix(label, discarded_label)
                or utils.string_prefix(discarded_label, label) then
                return false
            end
        end

        return true
    end

    local generate_labels_if_needed = function()
        if generated then return end
        generated = true

        while true do
            local tail = {}

            if labels.first() == nil then
                -- first labels are equal to atoms
                for _, atom in ipairs(atoms) do
                    if available(atom) then
                        table.insert(tail, atom)
                    end
                end
            else
                -- concatenate atoms to create more labels if needed
                for _, label in labels.pairs() do
                    for _, atom in ipairs(atoms) do
                        if atom ~= label:sub(-#atom) then -- skip atom if it's equal
                                                          -- to the labels last char
                            local new_label = label .. atom

                            if #new_label <= max_len and available(new_label) then
                                table.insert(tail, new_label)
                            end
                        end
                    end
                end
            end

            -- nothing generated, break to prevent infinite loop
            if next(tail) == nil then
                return
            end

            for _, label in ipairs(tail) do
                -- add freshly generated label to the pool
                -- and remove its prefix to avoid ambiguity
                local prefix = label:sub(1, -2)
                labels.remove_value(prefix)
                labels.append(label)

                if labels.count() >= min_count then
                    return
                end
            end
        end
    end

    local this = {}

    this.available = available

    this.discard = function(label)
        assert(not generated)
        assert(label ~= nil)
        assert(label ~= "")
        discarded[label] = true
    end

    this.first = function()
        generate_labels_if_needed()
        return labels.first()
    end

    this.take = function()
        generate_labels_if_needed()
        return labels.drop_first()
    end

    return this
end

local function sort_matches(matches, sorted_matches)
    -- sort matches by distance to the middle line of the visible bounds
    local win_bounds = {}

    for _, win_matches in ipairs(matches.wins) do
        win_bounds[win_matches.win_id] = win_matches.bounds

        for _, match in ipairs(win_matches.list) do
            table.insert(sorted_matches, match)
        end
    end

    table.sort(sorted_matches, function(match1, match2)
        local bounds1 = win_bounds[match1.win_id]
        local bounds2 = win_bounds[match2.win_id]
        local middle_line1 = math.floor(bounds1.top + (bounds1.bottom - bounds1.top) / 2)
        local middle_line2 = math.floor(bounds2.top + (bounds2.bottom - bounds2.top) / 2)
        local dist1 = math.abs(match1.line - middle_line1)
        local dist2 = math.abs(match2.line - middle_line2)

        if dist1 ~= dist2 then return dist1 < dist2 end
        if match1.line ~= match2.line then return match1.line < match2.line end
        if match1.col ~= match2.col then return match1.col < match2.col end
        return match1.win_id < match2.win_id
    end)
end

-- positive foresight: discard `foresight` characters from start of the match
-- negative foresight: discard every character in the match
local function discard_conflicting_labels(foresight, labels_pool, matches, buf)
    -- discard labels that may conflict with next possible query character
    for _, match in ipairs(matches) do
        local start = foresight >= 0
            and match.col + match.len
             or match.col

        local stop = math.max(match.col + foresight, match.col + match.len)

        for col = start, stop do
            local char_pos = { line = match.line, col = col }
            local next_char = buf.char_at(char_pos):lower()
            if next_char == "" then break end

            labels_pool.discard(next_char)
        end
    end
end

local function label_prev_matches(matches, labels_pool, prev_labeled_matches, labeled_matches)
    -- try to take lables from previous search
    for _, match in ipairs(matches) do
        local label = prev_labeled_matches.key(match)

        if label ~= nil and labels_pool.available(label) then
            labels_pool.discard(label)
            labeled_matches.set(label, match)
        end
    end
end

local function label_matches(matches, labels_pool, labeled_matches)
    -- take labels from the pool
    for _, match in ipairs(matches) do
        local label = labels_pool.first()

        if label ~= nil then
            labels_pool.take()
            local prev_label = labeled_matches.key(match)

            if prev_label == nil then
                labeled_matches.set(label, match)
            elseif #label < #prev_label then -- replace label from previous
                                             -- search with shorter one
                labeled_matches.replace(prev_label, label, match)
            end
        end
    end
end

local function discard_irrelevant_labels(labeled_matches, current_label)
    -- discard irrelevant labels after start typing label to go to
    for label, _ in labeled_matches.pairs() do
        if not utils.string_prefix(label, current_label) then
            labeled_matches.remove_key(label)
        end
    end
end

local function discard_offwindow_labels(labeled_matches, excluded_win_ids)
    -- discard labels from excluded windows
    for _, match in labeled_matches.pairs() do
        if excluded_win_ids[match.win_id] ~= nil then
            labeled_matches.remove_value(match)
        end
    end
end

local function discard_offscreen_labels(labeled_matches, bounds)
    -- discard labels out of the current visible bounds
    for _, match in labeled_matches.pairs() do
        if match.line < bounds.top or match.line > bounds.bottom then
            labeled_matches.remove_value(match)
        end
    end
end

local M = {}

-- todo: find a way to test this function
function M.make_context(config, buf, win, excluded_win_ids)
    local history = {}
    local labeled_matches = make_matches_bimap()

    -- convert atoms string to array
    local atoms = {}
    config.label_atoms:gsub(".", function(char) table.insert(atoms, char) end)

    local this = {}

    this.label_matches = function(matches, exact, query, label)
        -- query too short to label matches, break
        if query == "" or #query < config.label_min_query_len then
            history = {}
            labeled_matches = make_matches_bimap()
            return
        end

        labeled_matches = history[query] ~= nil
            and history[query].copy()
            or make_matches_bimap()

        -- labels from previous search
        local prev_query = query:sub(1, -2)
        local prev_labeled_matches = history[prev_query] ~= nil
            and history[prev_query].copy()
            or make_matches_bimap()

        local labels_pool = make_labels_pool(atoms, matches.count, config.label_max_len)

        -- discard invalid labels
        for _, win_matches in ipairs(matches.wins) do
            win.run_on(win_matches.win_id, function()
                -- for regex search discard every char in the match
                local foresight = exact and config.label_foresight or -1
                discard_offscreen_labels(labeled_matches, win_matches.bounds)
                discard_conflicting_labels(foresight, labels_pool, win_matches.list, buf)
            end)
        end

        -- sort and label matches
        local sorted_matches = {}
        sort_matches(matches, sorted_matches)
        label_prev_matches(sorted_matches, labels_pool, prev_labeled_matches, labeled_matches)
        label_matches(sorted_matches, labels_pool, labeled_matches)

        history[query] = labeled_matches.copy()

        -- postprocess filters
        discard_offwindow_labels(labeled_matches, excluded_win_ids)

        if config.label_hide_irrelevant and label ~= "" then
            discard_irrelevant_labels(labeled_matches, label)
        end
    end

    this.labeled_matches = function()
        return labeled_matches
    end

    this.labels = function()
        return labeled_matches.keys()
    end

    this.has_label = function(label)
        return labeled_matches.has_key(label)
    end

    this.match = function(label)
        return labeled_matches.value(label)
    end

    return this
end

function M.test(tests)
    -- make_labels_pool
    do
        local atoms = { "a", "b", "c", "d" }

        -- generate labels
        local labels_pool = make_labels_pool(atoms, 1, 1)
        assert(labels_pool.available("a"))
        assert(labels_pool.available("b"))
        assert(labels_pool.available("c"))
        assert(labels_pool.available("d"))

        -- try to generate more labels with max label length = 1
        labels_pool = make_labels_pool(atoms, 6, 1)
        tests.assert_eq(labels_pool.take(), "a")
        tests.assert_eq(labels_pool.take(), "b")
        tests.assert_eq(labels_pool.take(), "c")
        tests.assert_eq(labels_pool.take(), "d")
        tests.assert_eq(labels_pool.take(), nil)

        -- generate more labels with max label length = 2
        labels_pool = make_labels_pool(atoms, 6, 2)
        tests.assert_eq(labels_pool.take(), "b")
        tests.assert_eq(labels_pool.take(), "c")
        tests.assert_eq(labels_pool.take(), "d")
        tests.assert_eq(labels_pool.take(), "ab")
        tests.assert_eq(labels_pool.take(), "ac")
        tests.assert_eq(labels_pool.take(), "ad")
        tests.assert_eq(labels_pool.take(), nil)

        -- discard single atom label
        labels_pool = make_labels_pool(atoms, 6, 2)
        labels_pool.discard("a")
        assert(not labels_pool.available("a"))
        assert(not labels_pool.available("ab"))
        tests.assert_eq(labels_pool.take(), "d")
        tests.assert_eq(labels_pool.take(), "ba")
        tests.assert_eq(labels_pool.take(), "bc")
        tests.assert_eq(labels_pool.take(), "bd")
        tests.assert_eq(labels_pool.take(), "ca")
        tests.assert_eq(labels_pool.take(), "cb")
        tests.assert_eq(labels_pool.take(), nil)

        -- discard multi-atom label
        labels_pool = make_labels_pool(atoms, 6, 2)
        labels_pool.discard("bla")
        -- b, bl, (bla), bla* must be discarded
        assert(not labels_pool.available("b"))
        assert(not labels_pool.available("bl"))
        assert(not labels_pool.available("bla"))
        assert(not labels_pool.available("blaz"))
        -- bz, blz must be available
        assert(labels_pool.available("bz"))
        assert(labels_pool.available("blz"))

        -- take first label
        labels_pool = make_labels_pool(atoms, 3, 2)
        local first_label = labels_pool.first()
        tests.assert_eq(labels_pool.take(), first_label)
    end

    -- sort_matches
    do
        local sorted_matches = {}
        local matches = { wins = {
            {
                win_id = 1,
                bounds = { top = 1, bottom = 9 },
                list = {
                    { win_id = 1, line = 2, col = 1 },
                    { win_id = 1, line = 5, col = 1 },
                    { win_id = 1, line = 7, col = 1 },
                },
            },
            {
                win_id = 2,
                bounds = { top = 1, bottom = 3 },
                list = {
                    { win_id = 2, line = 2, col = 1 },
                    { win_id = 2, line = 1, col = 1 },
                },
            },
        } }
        sort_matches(matches, sorted_matches) -- sorted matches is flat
        tests.assert_eq(sorted_matches[1], { win_id = 2, line = 2, col = 1 })
        tests.assert_eq(sorted_matches[2], { win_id = 1, line = 5, col = 1 })
        tests.assert_eq(sorted_matches[3], { win_id = 2, line = 1, col = 1 })
        tests.assert_eq(sorted_matches[4], { win_id = 1, line = 7, col = 1 })
        tests.assert_eq(sorted_matches[5], { win_id = 1, line = 2, col = 1 })
    end

    -- discard_conflicting_labels
    do
        local buf = { char_at = function(pos) return ("test line"):sub(pos.col, pos.col) end }

        -- foresight = 1, len = 1
        local labels_pool = make_labels_pool({}, 1, 1)
        local matches = { { line = 1, col = 1, len = 1 }, { line = 1, col = 6, len = 1 } }
        discard_conflicting_labels(1, labels_pool, matches, buf)
        assert(not labels_pool.available("e"))
        assert(not labels_pool.available("in"))
        assert(labels_pool.available("s"))
        assert(labels_pool.available("n"))

        -- foresight = 2, len = 1
        labels_pool = make_labels_pool({}, 1, 1)
        discard_conflicting_labels(2, labels_pool, matches, buf)
        assert(not labels_pool.available("e"))
        assert(not labels_pool.available("in"))
        assert(not labels_pool.available("s"))
        assert(not labels_pool.available("n"))

        -- foresight = 2, len = 2
        labels_pool = make_labels_pool({}, 1, 1)
        matches = { { line = 1, col = 1, len = 2 } }
        discard_conflicting_labels(2, labels_pool, matches, buf)
        assert(not labels_pool.available("s"))
        assert(labels_pool.available("e"))
        assert(labels_pool.available("t"))

        -- foresight = -1, discard every character in the match
        labels_pool = make_labels_pool({}, 1, 1)
        matches = { { line = 1, col = 1, len = 4 } }
        discard_conflicting_labels(-1, labels_pool, matches, buf)
        assert(not labels_pool.available("t"))
        assert(not labels_pool.available("e"))
        assert(not labels_pool.available("s"))
        assert(not labels_pool.available("t"))
        assert(labels_pool.available("l"))
        assert(labels_pool.available("i"))
        assert(labels_pool.available("n"))
    end

    -- label_prev_matches
    do
        local matches = {
            { line = 2, col = 1 },
            { line = 5, col = 1 },
            { line = 7, col = 1 },
            { line = 8, col = 1 },
            { line = 9, col = 1 },
        }
        local labels_pool = make_labels_pool({ "a", "b", "c", "d", "e", "f" }, #matches, 2)
        local prev_labeled_matches = utils.make_bimap({
            x = { line = 2, col = 1 },
            c = { line = 9, col = 1 },
            zz = { line = 7, col = 1 },
        })
        local labeled_matches = utils.make_bimap()
        label_prev_matches(matches, labels_pool, prev_labeled_matches, labeled_matches)

        -- take labels from `prev_labeled_matches`
        tests.assert_eq(labeled_matches.value("x"), { line = 2, col = 1 })
        tests.assert_eq(labeled_matches.value("c"), { line = 9, col = 1 })
        tests.assert_eq(labeled_matches.value("zz"), { line = 7, col = 1 })

        -- skip discarded labels
        labels_pool.discard("zz")
        labeled_matches = utils.make_bimap()
        label_prev_matches(matches, labels_pool, prev_labeled_matches, labeled_matches)

        tests.assert_eq(labeled_matches.value("zz"), nil)
    end

    -- label_matches
    do
        local matches = {
            { line = 2, col = 1 },
            { line = 5, col = 1 },
            { line = 7, col = 1 },
            { line = 8, col = 1 },
            { line = 9, col = 1 },
        }
        local labels_pool = make_labels_pool({ "a", "b", "c", "d", "e", "f" }, #matches, 2)
        local labeled_matches = utils.make_bimap({
            x = { line = 2, col = 1 },
            c = { line = 9, col = 1 },
            zz = { line = 7, col = 1 },
        })
        label_matches(matches, labels_pool, labeled_matches)

        -- use existing labels from `labeled_matches`
        -- otherwise use labels from `labels_pool`
        tests.assert_eq(labeled_matches.value("b"), { line = 5, col = 1 })
        tests.assert_eq(labeled_matches.value("c"), { line = 7, col = 1 }) -- since c is shorter than zz
        tests.assert_eq(labeled_matches.value("d"), { line = 8, col = 1 })
        tests.assert_eq(labeled_matches.value("e"), { line = 9, col = 1 })
        tests.assert_eq(labeled_matches.value("x"), { line = 2, col = 1 })
    end

    -- discard_offwindow_labels
    do
        local labeled_matches = utils.make_bimap({
            x = { win_id = 1, line = 2, col = 1 },
            c = { win_id = 1, line = 9, col = 1 },
            zz = { win_id = 2, line = 7, col = 1 },
        })
        local excluded_win_ids = { [2] = true }
        discard_offwindow_labels(labeled_matches, excluded_win_ids)

        -- labels in `excluded_win_ids` windows should be discarded
        tests.assert_eq(labeled_matches.value("zz"), nil)
        tests.assert_eq(labeled_matches.value("x"), { win_id = 1, line = 2, col = 1 })
        tests.assert_eq(labeled_matches.value("c"), { win_id = 1, line = 9, col = 1 })
    end

    -- discard_offscreen_labels
    do
        local labeled_matches = utils.make_bimap({
            x = { line = 2, col = 1 },
            c = { line = 9, col = 1 },
            zz = { line = 7, col = 1 },
        })
        local bounds = { top = 1, bottom = 7 }
        discard_offscreen_labels(labeled_matches, bounds)

        -- labels outside of `bounds` should be didcarded
        tests.assert_eq(labeled_matches.value("c"), nil)
        tests.assert_eq(labeled_matches.value("x"), { line = 2, col = 1 })
        tests.assert_eq(labeled_matches.value("zz"), { line = 7, col = 1 })
    end

    -- discard_irrelevant_labels
    do
        local labeled_matches = utils.make_bimap({ aa = { 2, 1 }, ba = { 3, 1 }, bb = { 1, 1 } })
        local current_label = "b"
        discard_irrelevant_labels(labeled_matches, current_label)

        -- labels not starting with `current_label` should be discarded
        tests.assert_eq(labeled_matches.value("aa"), nil)
        tests.assert_eq(labeled_matches.key({ 3, 1 }), "ba")
        tests.assert_eq(labeled_matches.key({ 1, 1 }), "bb")
    end
end

return M
