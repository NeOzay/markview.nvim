-- Tests for utility functions in lua/markview/parser.lua:
-- deep_extend, create_ignore_range, parse_links
local new_set = MiniTest.new_set
local expect = MiniTest.expect

local H = require("tests.helpers")

local T = new_set({
  hooks = {
    post_case = function()
      vim.cmd("silent %bwipeout!")
    end,
  },
})

-- ── deep_extend ───────────────────────────────────────────────────────────────

T["deep_extend"] = new_set()

T["deep_extend"]["empty tbl_1 plus populated tbl_2 copies all keys"] = function()
  local parser = require("markview.parser")
  local result = parser.deep_extend({}, { a = 1, b = 2 })
  expect.equality(result.a, 1)
  expect.equality(result.b, 2)
end

T["deep_extend"]["tbl_2 scalar overwrites tbl_1 scalar"] = function()
  local parser = require("markview.parser")
  local result = parser.deep_extend({ a = 1 }, { a = 99 })
  expect.equality(result.a, 99)
end

T["deep_extend"]["lists are concatenated not overwritten"] = function()
  local parser = require("markview.parser")
  local result = parser.deep_extend({ a = { 1, 2 } }, { a = { 3, 4 } })
  expect.equality(result.a, { 1, 2, 3, 4 })
end

T["deep_extend"]["nested tables are merged recursively"] = function()
  local parser = require("markview.parser")
  local result = parser.deep_extend({ a = { b = 1 } }, { a = { c = 2 } })
  expect.equality(result.a.b, 1)
  expect.equality(result.a.c, 2)
end

T["deep_extend"]["tbl_1 key absent from tbl_2 is preserved"] = function()
  local parser = require("markview.parser")
  local result = parser.deep_extend({ x = 42 }, { y = 7 })
  expect.equality(result.x, 42)
  expect.equality(result.y, 7)
end

-- ── create_ignore_range ───────────────────────────────────────────────────────

T["create_ignore_range"] = new_set({
  hooks = {
    pre_case = function()
      -- reset global state accumulated by previous tests
      require("markview.parser").ignore_ranges = {}
    end,
  },
})

T["create_ignore_range"]["markdown with no code blocks returns empty list"] = function()
  local parser = require("markview.parser")
  local result = parser.create_ignore_range("markdown", {})
  expect.equality(result, {})
end

T["create_ignore_range"]["markdown code block row range is captured"] = function()
  local parser = require("markview.parser")
  local items = {
    markdown_code_block = {
      { range = { row_start = 2, row_end = 5 } },
    },
  }
  local result = parser.create_ignore_range("markdown", items)
  expect.equality(#result, 1)
  expect.equality(result[1][1], 2)
  expect.equality(result[1][2], 5)
end

T["create_ignore_range"]["two code blocks produce two ranges"] = function()
  local parser = require("markview.parser")
  local items = {
    markdown_code_block = {
      { range = { row_start = 0, row_end = 3 } },
      { range = { row_start = 5, row_end = 8 } },
    },
  }
  local result = parser.create_ignore_range("markdown", items)
  expect.equality(#result, 2)
end

T["create_ignore_range"]["unknown language returns empty list"] = function()
  local parser = require("markview.parser")
  -- html is not handled → should return empty
  local result = parser.create_ignore_range("html", {
    html_block = { { range = { row_start = 0, row_end = 2 } } },
  })
  expect.equality(result, {})
end

T["create_ignore_range"]["typst raw block range is captured"] = function()
  local parser = require("markview.parser")
  local items = {
    typst_raw_block = {
      { range = { row_start = 1, row_end = 4 } },
    },
  }
  local result = parser.create_ignore_range("typst", items)
  expect.equality(#result, 1)
  expect.equality(result[1][1], 1)
  expect.equality(result[1][2], 4)
end

-- ── parse_links ───────────────────────────────────────────────────────────────

T["parse_links"] = new_set()

T["parse_links"]["atx heading is registered as GFM anchor"] = function()
  -- parse_links registers headings as anchor targets, not [label]: url definitions.
  -- The key is the GFM slug (lowercase, spaces→dashes, punctuation stripped).
  local buf = H.setup_buf({ "# Hello World" })
  require("markview.parser").parse_links(buf)
  local ref = require("markview.links").get(buf, "hello-world")
  expect.equality(ref ~= nil, true)
  expect.equality(ref.row_start, 0)
end

T["parse_links"]["setext heading is registered as GFM anchor"] = function()
  local buf = H.setup_buf({ "My Section", "==========" })
  require("markview.parser").parse_links(buf)
  local ref = require("markview.links").get(buf, "my-section")
  expect.equality(ref ~= nil, true)
  expect.equality(ref.row_start, 0)
end

T["parse_links"]["second heading on row 2 has correct row_start"] = function()
  local buf = H.setup_buf({ "# First", "", "# Second" })
  require("markview.parser").parse_links(buf)
  local ref = require("markview.links").get(buf, "second")
  expect.equality(ref ~= nil, true)
  expect.equality(ref.row_start, 2)
end

T["parse_links"]["GFM slug strips punctuation from heading text"] = function()
  local buf = H.setup_buf({ "# Hello, World!" })
  require("markview.parser").parse_links(buf)
  -- punctuation stripped → "hello-world"
  local ref = require("markview.links").get(buf, "hello-world")
  expect.equality(ref ~= nil, true)
end

T["parse_links"]["duplicate heading slug gets numeric suffix"] = function()
  local buf = H.setup_buf({ "# Dup", "", "# Dup" })
  require("markview.parser").parse_links(buf)
  local ref1 = require("markview.links").get(buf, "dup")
  local ref2 = require("markview.links").get(buf, "dup-1")
  -- both anchors must be registered
  expect.equality(ref1 ~= nil, true)
  expect.equality(ref2 ~= nil, true)
end

T["parse_links"]["buffer with no headings leaves reference table empty"] = function()
  local buf = H.setup_buf({ "plain paragraph, no headings here" })
  require("markview.parser").parse_links(buf)
  local links = require("markview.links")
  local ref = links.reference[buf]
  expect.equality(ref == nil or vim.tbl_isempty(ref), true)
end

return T
