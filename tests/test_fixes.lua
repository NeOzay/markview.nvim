-- Regression tests for bugs fixed in the current working diff.
-- Each test is annotated with the file and nature of the fix it guards.
local new_set = MiniTest.new_set
local expect = MiniTest.expect

local H = require("tests.helpers")
local md_str

local T = new_set({
  hooks = {
    pre_once = function()
      require("markview.spec")
      md_str = require("markview.renderers.markdown.tostring")
      md_str.update_cache()
    end,
    post_case = function()
      vim.cmd("silent %bwipeout!")
    end,
  },
})

-- ── Fix: emoji fallback returns raw match (tostring.lua:258) ─────────────────
--
-- BUG: md_str.emoji() returned `removed` (label without colons) when
--      emoji_shorthands was not configured, instead of the original `match`.
--      Width calculations got the emoji name length instead of the `:name:` length.

T["emoji"] = new_set()

T["emoji"]["returns full :name: match when emoji_shorthands is nil"] = function()
  local saved = md_str.cached_config
  md_str.cached_config = {}  -- simulate emoji_shorthands not configured

  local result = md_str.emoji(":rocket:")

  md_str.cached_config = saved
  -- Must return the full original token, not the stripped label.
  expect.equality(result, ":rocket:")
end

T["emoji"]["returns full match for multi-word-style shorthand"] = function()
  local saved = md_str.cached_config
  md_str.cached_config = {}

  local result = md_str.emoji(":thumbs_up:")

  md_str.cached_config = saved
  expect.equality(result, ":thumbs_up:")
end

T["emoji"]["tostring passes emoji through without stripping when unconfigured"] = function()
  local saved = md_str.cached_config
  -- Wipe emoji_shorthands so the fallback branch is taken.
  md_str.cached_config = { emoji_shorthands = nil }

  local result = md_str.tostring(-1, "hello :wave: world", false)

  md_str.cached_config = saved
  -- The ":wave:" token must survive intact in the output string.
  expect.equality(result:find(":wave:") ~= nil, true)
end

-- ── Fix: double-backtick code spans (tostring.lua lpeg grammar) ──────────────
--
-- BUG: The old single lpeg `code` pattern used `lpeg.P("`")^1` for both
--      delimiters, which allowed `` `` `x` `` `` to be mis-parsed: the
--      first `` ` `` inside the content terminated the span early.
--      The grammar now uses two distinct patterns: code_2 (double) before
--      code_1 (single) so the longer delimiter wins.

T["double-backtick code"] = new_set()

T["double-backtick code"]["span containing a single backtick is handled"] = function()
  -- "`` `inner` ``" must be treated as ONE span whose content is " `inner` ".
  -- With the old grammar this would split at the first "`".
  local result = md_str.tostring(-1, "`` `inner` ``", false)
  expect.equality(type(result), "string")
  -- The inner backtick character must appear in the output (not silently eaten).
  expect.equality(result:find("`") ~= nil, true)
  -- The identifier "inner" must survive.
  expect.equality(result:find("inner") ~= nil, true)
end

T["double-backtick code"]["span does not bleed into surrounding text"] = function()
  -- Surrounding words must not be consumed by the span.
  local result = md_str.tostring(-1, "before `` `x` `` after", false)
  expect.equality(result:find("before") ~= nil, true)
  expect.equality(result:find("after") ~= nil, true)
end

T["double-backtick code"]["adjacent single-backtick spans still work"] = function()
  -- Ensure code_2 priority does not break ordinary single-backtick spans.
  local result = md_str.tostring(-1, "`foo` and `bar`", false)
  expect.equality(result:find("foo") ~= nil, true)
  expect.equality(result:find("bar") ~= nil, true)
end

T["double-backtick code"]["single-backtick span is not mistaken for double"] = function()
  -- "`x`" must not be swallowed by the code_2 pattern (which requires "``").
  local result = md_str.tostring(-1, "`x`", false)
  expect.equality(result:find("x") ~= nil, true)
end

-- ── Fix / Feature: md_str.tag token in tostring pipeline (tostring.lua) ───────
--
-- Previously `#tag` tokens were not recognised by the lpeg grammar; each
-- character fell through to the `any` rule.  A new `md_str.tag` function and
-- a `tag` lpeg token were added so that `#tag` strings are routed correctly
-- for width calculations.

T["tag token"] = new_set()

T["tag token"]["#tag in tostring returns a string without error"] = function()
  local ok, result = pcall(md_str.tostring, -1, "#mytag", false)
  expect.equality(ok, true)
  expect.equality(type(result), "string")
  expect.equality(#result > 0, true)
end

T["tag token"]["tag label appears in output"] = function()
  -- Whatever decoration is applied, the raw label text must be present.
  local result = md_str.tostring(-1, "#hello", false)
  expect.equality(result:find("hello") ~= nil, true)
end

T["tag token"]["tag in running text does not corrupt surrounding words"] = function()
  local result = md_str.tostring(-1, "word #tag end", false)
  expect.equality(result:find("word") ~= nil, true)
  expect.equality(result:find("end") ~= nil, true)
end

T["tag token"]["md_str.tag without config returns original match"] = function()
  -- When tags are not configured, the raw "#tag" string must be returned
  -- so downstream callers get a predictable value.
  local saved = md_str.cached_config
  md_str.cached_config = { tags = nil }

  local result = md_str.tag("#hello")

  md_str.cached_config = saved
  expect.equality(result, "#hello")
end

T["tag token"]["md_str.tag strips leading # for label"] = function()
  -- With config present the label (without #) must be part of the output.
  local result = md_str.tag("#world")
  -- The label "world" must be somewhere in the rendered string.
  expect.equality(result:find("world") ~= nil, true)
end

-- ── Fix: code_span icon chunk in virt_text (markdown_inline.lua:69) ──────────
--
-- BUG: The opening extmark for an inline code span was missing the icon
--      virt_text chunk.  The virt_text array had only 2 entries
--      (corner_left + padding_left).  After the fix it has 3
--      (corner_left + padding_left + icon).

T["code_span icon"] = new_set()

T["code_span icon"]["opening mark has 3 virt_text chunks"] = function()
  local buf = H.setup_buf({ "some `code` here" })
  H.render(buf)

  local marks = H.get_extmarks(buf, "markview/inline")

  -- Find the opening conceal mark (col 5 = position of opening backtick).
  local opening = vim.tbl_filter(function(m)
    return m[2] == 0 and m[4].conceal ~= nil and m[4].virt_text ~= nil
  end, marks)

  expect.equality(#opening >= 1, true)
  -- Must have exactly 3 chunks: corner_left + padding_left + icon.
  expect.equality(#opening[1][4].virt_text, 3)
end

T["code_span icon"]["closing mark has 2 virt_text chunks (unchanged)"] = function()
  -- The closing mark (corner_right + padding_right) was not changed.
  local buf = H.setup_buf({ "some `code` here" })
  H.render(buf)

  local marks = H.get_extmarks(buf, "markview/inline")

  -- Find conceal marks; the one with the higher column is the closing mark.
  local conceal_marks = vim.tbl_filter(function(m)
    return m[2] == 0 and m[4].conceal ~= nil and m[4].virt_text ~= nil
  end, marks)

  -- Sort by column ascending; last one is closing.
  table.sort(conceal_marks, function(a, b)
    return a[3] < b[3]
  end)

  local closing = conceal_marks[#conceal_marks]
  expect.equality(#closing[4].virt_text, 2)
end

T["code_span icon"]["total virt_text chunks for opening went from 2 to 3"] = function()
  -- Explicit count guard: if this breaks back to 2, the icon was removed.
  local buf = H.setup_buf({ "`x`" })
  H.render(buf)

  local marks = H.get_extmarks(buf, "markview/inline")
  local opening = vim.tbl_filter(function(m)
    return m[2] == 0 and m[3] == 0 and m[4].conceal ~= nil and m[4].virt_text ~= nil
  end, marks)

  expect.equality(#opening, 1)
  expect.no_equality(#opening[1][4].virt_text, 2) -- must NOT be the old count
  expect.equality(#opening[1][4].virt_text, 3)    -- must be the new count
end

-- ── Fix #503: typst list item marker extmark priority = 150 ─────────────────
--
-- BUG: The conceal extmark for a Typst list item marker was placed with the
--      default priority (~100), which let semantic highlights (priority 125)
--      overwrite it and prevent concealment. The fix sets priority = 150.

T["typst list item priority"] = new_set({
  hooks = {
    pre_once = function()
      require("markview.spec")
    end,
  },
})

T["typst list item priority"]["conceal extmark has priority >= 150"] = function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "  - nested item" })

  local typst_renderer = require("markview.renderers.typst")

  local item = {
    class  = "typst_list_item",
    marker = "-",
    indent = 2,
    text   = { "  - nested item" },
    range  = { row_start = 0, row_end = 0, col_start = 2, col_end = 15 },
  }

  typst_renderer.list_item(buf, item)

  local ns_id = vim.api.nvim_get_namespaces()["markview/typst"]
  local marks  = ns_id and vim.api.nvim_buf_get_extmarks(
    buf, ns_id, { 0, 0 }, { -1, -1 }, { details = true }
  ) or {}

  local high_priority = vim.tbl_filter(function(m)
    return m[4].priority ~= nil and m[4].priority >= 150
  end, marks)

  expect.equality(#high_priority >= 1, true)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["typst list item priority"]["conceal extmark is a conceal mark"] = function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "  - nested item" })

  local typst_renderer = require("markview.renderers.typst")

  local item = {
    class  = "typst_list_item",
    marker = "-",
    indent = 2,
    text   = { "  - nested item" },
    range  = { row_start = 0, row_end = 0, col_start = 2, col_end = 15 },
  }

  typst_renderer.list_item(buf, item)

  local ns_id = vim.api.nvim_get_namespaces()["markview/typst"]
  local marks  = ns_id and vim.api.nvim_buf_get_extmarks(
    buf, ns_id, { 0, 0 }, { -1, -1 }, { details = true }
  ) or {}

  local conceal_marks = vim.tbl_filter(function(m)
    return m[4].conceal ~= nil and m[4].priority ~= nil and m[4].priority >= 150
  end, marks)

  expect.equality(#conceal_marks >= 1, true)
  vim.api.nvim_buf_delete(buf, { force = true })
end

return T
