-- ~/.config/nvim/lua/snippets/markdown.lua
local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

return {
    s("daily", fmt([[
---
title: Daily Standup - {}
date: {}
tags: [daily, standup, {}]
---

# Daily Standup - {}

## Team: {}

### What I did yesterday
- {}

### What I'm doing today
- {}

### Blockers / Issues
- {}

### Notes / Discussion
- {}
  ]], {
        i(1, os.date("%Y-%m-%d")), -- title date
        t(os.date("%Y-%m-%d")), -- frontmatter date
        i(2, "CoverGo"),     -- tag
        rep(1),                -- title heading
        rep(2),                -- team name
        i(3), i(4), i(5), i(6) -- sections
    })),
    -- Note Template
    s("quicknote", {
        t({ "---",
            "title: " }), i(1, "Quick note"), t({ "",
        "date: " }), t(os.date("%Y-%m-%d")), t({ "",
        "tags: [", }), i(2, "tag1, tag2"), t({ "]",
        "---", "",
        "# " }), i(3, "Quick Note"), t({ "",
        "", }), i(0),
    }),
}
