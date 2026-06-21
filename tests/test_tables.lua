-- Regression tests for markdown table rendering.
-- Tables require a window to render (the renderer reads window width and wrap
-- state), so every test here uses H.setup_windowed_buf().
local new_set = MiniTest.new_set
local expect = MiniTest.expect

local H = require("tests.helpers")

-- Reusable table fixtures.
local SIMPLE = {
  "| A | B |",
  "| - | - |",
  "| 1 | 2 |",
}

local ALIGNED = {
  "| Name  | Age |",
  "| :---- | --: |",
  "| Alice |  30 |",
  "| Bob   |  25 |",
}

local WIDE = {
  "| Col1 | Col2 | Col3 |",
  "| ---- | ---- | ---- |",
  "| a    | b    | c    |",
}

local T = new_set({
  hooks = {
    post_case = function()
      vim.cmd("%bwipeout!")
    end,
  },
})

-- ── Parser: node structure ────────────────────────────────────────────────────

T["parser"] = new_set()

T["parser"]["simple table produces markdown_table node"] = function()
  local buf, win = H.setup_windowed_buf(SIMPLE)
  local content, _ = require("markview.parser").init(buf, 0, -1, false)
  vim.api.nvim_win_close(win, true)

  local tables = vim.tbl_filter(function(n)
    return n.class == "markdown_table"
  end, content.markdown or {})

  expect.equality(#tables, 1)
end

T["parser"]["header contains column nodes"] = function()
  local buf, win = H.setup_windowed_buf(SIMPLE)
  local content, _ = require("markview.parser").init(buf, 0, -1, false)
  vim.api.nvim_win_close(win, true)

  local tbl = vim.tbl_filter(function(n)
    return n.class == "markdown_table"
  end, content.markdown or {})[1]

  local cols = vim.tbl_filter(function(c)
    return c.class == "column"
  end, tbl.header)

  expect.equality(#cols, 2) -- "A" and "B"
end

T["parser"]["data rows are counted correctly"] = function()
  local buf, win = H.setup_windowed_buf(ALIGNED)
  local content, _ = require("markview.parser").init(buf, 0, -1, false)
  vim.api.nvim_win_close(win, true)

  local tbl = vim.tbl_filter(function(n)
    return n.class == "markdown_table"
  end, content.markdown or {})[1]

  expect.equality(#tbl.rows, 2) -- Alice + Bob
end

T["parser"]["alignments are detected"] = function()
  local buf, win = H.setup_windowed_buf(ALIGNED)
  local content, _ = require("markview.parser").init(buf, 0, -1, false)
  vim.api.nvim_win_close(win, true)

  local tbl = vim.tbl_filter(function(n)
    return n.class == "markdown_table"
  end, content.markdown or {})[1]

  expect.equality(tbl.has_alignment_markers, true)
  expect.equality(tbl.alignments[1], "left")
  expect.equality(tbl.alignments[2], "right")
end

T["parser"]["no-alignment table has has_alignment_markers=false"] = function()
  local buf, win = H.setup_windowed_buf(SIMPLE)
  local content, _ = require("markview.parser").init(buf, 0, -1, false)
  vim.api.nvim_win_close(win, true)

  local tbl = vim.tbl_filter(function(n)
    return n.class == "markdown_table"
  end, content.markdown or {})[1]

  expect.equality(tbl.has_alignment_markers, false)
end

T["parser"]["row_start is 0 for first-line table"] = function()
  local buf, win = H.setup_windowed_buf(SIMPLE)
  local content, _ = require("markview.parser").init(buf, 0, -1, false)
  vim.api.nvim_win_close(win, true)

  local tbl = vim.tbl_filter(function(n)
    return n.class == "markdown_table"
  end, content.markdown or {})[1]

  expect.equality(tbl.range.row_start, 0)
end

T["parser"]["three-column table parses 3 columns"] = function()
  local buf, win = H.setup_windowed_buf(WIDE)
  local content, _ = require("markview.parser").init(buf, 0, -1, false)
  vim.api.nvim_win_close(win, true)

  local tbl = vim.tbl_filter(function(n)
    return n.class == "markdown_table"
  end, content.markdown or {})[1]

  local cols = vim.tbl_filter(function(c)
    return c.class == "column"
  end, tbl.header)

  expect.equality(#cols, 3)
end

-- ── Renderer: extmark output ──────────────────────────────────────────────────

T["renderer"] = new_set()

T["renderer"]["places extmarks on every table row"] = function()
  local buf, win = H.setup_windowed_buf(SIMPLE)
  H.render(buf)
  vim.api.nvim_win_close(win, true)

  local marks = H.get_extmarks(buf, "markview/markdown")
  local rows_with_marks = {}
  for _, m in ipairs(marks) do
    rows_with_marks[m[2]] = true
  end

  -- Rows 0 (header), 1 (separator), 2 (data) must all have extmarks.
  expect.equality(rows_with_marks[0], true)
  expect.equality(rows_with_marks[1], true)
  expect.equality(rows_with_marks[2], true)
end

T["renderer"]["pipe separators are concealed on header row"] = function()
  local buf, win = H.setup_windowed_buf(SIMPLE)
  H.render(buf)
  vim.api.nvim_win_close(win, true)

  local marks = H.get_extmarks(buf, "markview/markdown")
  local conceal = H.conceal_at(marks, 0)
  -- Header "| A | B |" has 3 pipe chars → 3 conceal extmarks.
  expect.equality(#conceal >= 3, true)
end

T["renderer"]["pipe separators are concealed on data rows"] = function()
  local buf, win = H.setup_windowed_buf(SIMPLE)
  H.render(buf)
  vim.api.nvim_win_close(win, true)

  local marks = H.get_extmarks(buf, "markview/markdown")
  local conceal = H.conceal_at(marks, 2) -- data row "| 1 | 2 |"
  expect.equality(#conceal >= 3, true)
end

T["renderer"]["bottom border uses virt_lines at end of buffer"] = function()
  -- When the table ends at EOF, virt_text on the non-existent row_end is invisible.
  -- The border must use virt_lines (no virt_lines_above) on the last real row.
  local buf, win = H.setup_windowed_buf(SIMPLE)
  H.render(buf)
  vim.api.nvim_win_close(win, true)

  local marks = H.get_extmarks(buf, "markview/markdown")
  local border = vim.tbl_filter(function(m)
    return m[2] == 2 and m[4].virt_lines ~= nil and not m[4].virt_lines_above
  end, marks)

  expect.equality(#border >= 1, true)
end

T["renderer"]["extmark count is stable for 2-col simple table"] = function()
  -- 3 pipes × 3 rows  + 2 separator internals + top border (virt_lines_above
  -- on row 0, visible by scrolling up) + bottom border = 13 extmarks.
  -- If this breaks, the table rendering structure has changed.
  local buf, win = H.setup_windowed_buf(SIMPLE)
  H.render(buf)
  vim.api.nvim_win_close(win, true)

  local marks = H.get_extmarks(buf, "markview/markdown")
  expect.equality(#marks, 13)
end

T["renderer"]["4-row aligned table places extmarks on all data rows"] = function()
  local buf, win = H.setup_windowed_buf(ALIGNED)
  H.render(buf)
  vim.api.nvim_win_close(win, true)

  local marks = H.get_extmarks(buf, "markview/markdown")
  local rows_with_marks = {}
  for _, m in ipairs(marks) do
    rows_with_marks[m[2]] = true
  end

  for i = 0, 3 do
    expect.equality(rows_with_marks[i], true)
  end
end

-- ── Edge cases ────────────────────────────────────────────────────────────────

T["edge cases"] = new_set()

T["edge cases"]["single-row table (header only, no data) is parsed"] = function()
  local buf, win = H.setup_windowed_buf({
    "| X |",
    "| - |",
  })
  local content, _ = require("markview.parser").init(buf, 0, -1, false)
  vim.api.nvim_win_close(win, true)

  local tables = vim.tbl_filter(function(n)
    return n.class == "markdown_table"
  end, content.markdown or {})

  expect.equality(#tables, 1)
  expect.equality(#tables[1].rows, 0)
end

T["edge cases"]["table after heading is parsed correctly"] = function()
  local buf, win = H.setup_windowed_buf({
    "# Title",
    "",
    "| A | B |",
    "| - | - |",
    "| 1 | 2 |",
  })
  local content, _ = require("markview.parser").init(buf, 0, -1, false)
  vim.api.nvim_win_close(win, true)

  local tables = vim.tbl_filter(function(n)
    return n.class == "markdown_table"
  end, content.markdown or {})

  expect.equality(#tables, 1)
  expect.equality(tables[1].range.row_start, 2) -- table starts at row 2
end

-- ── Border overlap prevention ─────────────────────────────────────────────────
-- Regression: when a table directly follows content (no blank line), the top/
-- bottom border extmarks must NOT be placed as inline virt_text on the adjacent
-- content line (which caused visual overlap with heading/paragraph decorations).
-- They must instead use virt_lines_above on the table's own first/last row.

T["border overlap"] = new_set()


T["border overlap"]["top border uses virt_lines_above when table is at top of file"] = function()
  -- Table at row 0: no previous line, virt_lines_above is used.
  -- The virtual line is visible by scrolling up past row 0.
  local buf, win = H.setup_windowed_buf(SIMPLE)
  H.render(buf)
  vim.api.nvim_win_close(win, true)

  local marks = H.get_extmarks(buf, "markview/markdown")
  local top_border = vim.tbl_filter(function(m)
    return m[2] == 0 and m[4].virt_lines ~= nil and m[4].virt_lines_above == true
  end, marks)
  expect.equality(#top_border >= 1, true)
end

T["border overlap"]["top border uses virt_lines_above when previous line has content"] = function()
  -- Table at row 1, heading at row 0 (10 chars — past col_start=0).
  local buf, win = H.setup_windowed_buf({
    "### Signes",
    "| Signe | Texte |",
    "| ----- | ----- |",
    "| Foo   | Bar   |",
  })
  H.render(buf)
  vim.api.nvim_win_close(win, true)

  local marks = H.get_extmarks(buf, "markview/markdown")

  -- Must NOT have a virt_text on row 0 (the heading line) containing the top-left
  -- corner character — that would mean the border overlaps the heading.
  local overlap = vim.tbl_filter(function(m)
    if m[2] ~= 0 or not m[4].virt_text then return false end
    for _, chunk in ipairs(m[4].virt_text) do
      if chunk[1]:find("╭") or chunk[1]:find("┌") then return true end
    end
    return false
  end, marks)
  expect.equality(#overlap, 0)

  -- Must have a virt_lines_above extmark on row 1 (the table's first row).
  local virt_lines = vim.tbl_filter(function(m)
    return m[2] == 1 and m[4].virt_lines ~= nil
  end, marks)
  expect.equality(#virt_lines >= 1, true)
end

T["border overlap"]["top border uses inline when previous line is empty"] = function()
  -- Empty line between heading and table: original inline behavior must be kept.
  local buf, win = H.setup_windowed_buf({
    "# Title",
    "",
    "| A | B |",
    "| - | - |",
    "| 1 | 2 |",
  })
  H.render(buf)
  vim.api.nvim_win_close(win, true)

  local marks = H.get_extmarks(buf, "markview/markdown")

  -- The empty line (row 1) should carry the top border as inline virt_text.
  local inline_on_empty = vim.tbl_filter(function(m)
    return m[2] == 1 and m[4].virt_text ~= nil
  end, marks)
  expect.equality(#inline_on_empty >= 1, true)

  -- No virt_lines_above on row 2 (table start) — not needed when prev is empty.
  local virt_lines = vim.tbl_filter(function(m)
    return m[2] == 2 and m[4].virt_lines ~= nil
  end, marks)
  expect.equality(#virt_lines, 0)
end

T["border overlap"]["bottom border uses virt_lines when next line has content"] = function()
  -- A heading directly after the table terminates the pipe_table TS node,
  -- so the renderer sees next_line > col_start and places virt_lines below
  -- the last real table row (row_end - 1) instead of virt_text on row_end.
  local buf, win = H.setup_windowed_buf({
    "| A | B |",
    "| - | - |",
    "| 1 | 2 |",
    "## After",
  })
  H.render(buf)
  vim.api.nvim_win_close(win, true)

  local marks = H.get_extmarks(buf, "markview/markdown")

  -- Must NOT have TABLE bottom-border characters as inline virt_text on row 3.
  local table_border_inline = vim.tbl_filter(function(m)
    if m[2] ~= 3 or not m[4].virt_text then return false end
    for _, chunk in ipairs(m[4].virt_text) do
      if chunk[1]:find("╰") or chunk[1]:find("└") then return true end
    end
    return false
  end, marks)
  expect.equality(#table_border_inline, 0)

  -- Must have virt_lines_above on row 3 (attached to the heading, above it).
  local virt_lines = vim.tbl_filter(function(m)
    return m[2] == 3 and m[4].virt_lines ~= nil and m[4].virt_lines_above == true
  end, marks)
  expect.equality(#virt_lines >= 1, true)
end

T["border overlap"]["bottom border uses virt_lines at end of buffer"] = function()
  -- Table is the last content: virt_text on row_end (past buffer) is invisible;
  -- the renderer must use virt_lines on the last real row (row_end - 1) instead.
  local buf, win = H.setup_windowed_buf(SIMPLE)
  H.render(buf)
  vim.api.nvim_win_close(win, true)

  local marks = H.get_extmarks(buf, "markview/markdown")

  -- virt_lines (no virt_lines_above) on row 2 = last real table row.
  local border = vim.tbl_filter(function(m)
    return m[2] == 2 and m[4].virt_lines ~= nil and not m[4].virt_lines_above
  end, marks)
  expect.equality(#border >= 1, true)
end

T["border overlap"]["both borders use virt_lines_above when table is surrounded by content"] = function()
  local buf, win = H.setup_windowed_buf({
    "### Before",
    "| A | B |",
    "| - | - |",
    "| 1 | 2 |",
    "### After",
  })
  H.render(buf)
  vim.api.nvim_win_close(win, true)

  local marks = H.get_extmarks(buf, "markview/markdown")

  -- No inline virt_text on row 0 (heading before) with corner characters.
  local top_overlap = vim.tbl_filter(function(m)
    if m[2] ~= 0 or not m[4].virt_text then return false end
    for _, chunk in ipairs(m[4].virt_text) do
      if chunk[1]:find("╭") or chunk[1]:find("┌") then return true end
    end
    return false
  end, marks)
  expect.equality(#top_overlap, 0)

  -- No TABLE bottom-border characters as inline virt_text on row 4 (heading after).
  -- Note: the heading renderer also places its own virt_text decoration on row 4,
  -- so we check for corner characters only, not virt_text == nil.
  local bottom_overlap = vim.tbl_filter(function(m)
    if m[2] ~= 4 or not m[4].virt_text then return false end
    for _, chunk in ipairs(m[4].virt_text) do
      if chunk[1]:find("╰") or chunk[1]:find("└") then return true end
    end
    return false
  end, marks)
  expect.equality(#bottom_overlap, 0)

  -- Top border: virt_lines_above on row 1 (table start).
  local top_vl = vim.tbl_filter(function(m)
    return m[2] == 1 and m[4].virt_lines ~= nil
  end, marks)
  expect.equality(#top_vl >= 1, true)

  -- Bottom border: virt_lines_above on row 4 (attached above the heading after).
  local bottom_vl = vim.tbl_filter(function(m)
    return m[2] == 4 and m[4].virt_lines ~= nil and m[4].virt_lines_above == true
  end, marks)
  expect.equality(#bottom_vl >= 1, true)
end

return T
