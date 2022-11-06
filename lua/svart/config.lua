return {
    key_cancel = "<Esc>",      -- cancel search key
    key_delete_char = "<BS>",  -- delete query char key
    key_delete_word = "<C-W>", -- delete query word key
    key_best_match = "<CR>",   -- jump to the best match key
    key_next_match = "<C-N>",  -- select next match key
    key_prev_match = "<C-P>",  -- select prev match key

    label_atoms = "jfkdlsahgnuvrbytmiceoxwpqz", -- allowed label chars
    label_max_len = 2,                          -- max label length
    label_min_query_len = 1,                    -- min query length needed to show labels
    label_hide_irrelevant = true,               -- hide irrelevant labels after start typing label to go to

    search_begin_regular = true, -- begin regular (/) search after accepting match
    search_wrap_around = true,   -- wrap around when navigating to next/prev match
    search_multi_window = true,  -- search in multiple windows
}
