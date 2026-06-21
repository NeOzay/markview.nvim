-- Tests for lua/markview/parser.lua
-- Verifies that tree-sitter parsing produces the expected node structure
-- for common markdown constructs.
local new_set = MiniTest.new_set
local expect = MiniTest.expect

local H = require("tests.helpers")

local T = new_set({
  hooks = {
    post_case = function()
      vim.cmd("%bwipeout!")
    end,
  },
})

-- ── ATX Headings ─────────────────────────────────────────────────────────────

T["atx headings"] = new_set()

T["atx headings"]["h1 produces markdown_atx_heading node"] = function()
  local buf = H.setup_buf({ "# Hello" })
  local content, _ = require("markview.parser").init(buf, 0, -1, false)

  local headings = vim.tbl_filter(function(n)
    return n.class == "markdown_atx_heading"
  end, content.markdown or {})

  expect.equality(#headings >= 1, true)
  expect.equality(#headings[1].marker, 1) -- one "#"
end

T["atx headings"]["h2 has 2 markers"] = function()
  local buf = H.setup_buf({ "## World" })
  local content, _ = require("markview.parser").init(buf, 0, -1, false)

  local headings = vim.tbl_filter(function(n)
    return n.class == "markdown_atx_heading"
  end, content.markdown or {})

  expect.equality(#headings >= 1, true)
  expect.equality(#headings[1].marker, 2)
end

T["atx headings"]["h6 has 6 markers"] = function()
  local buf = H.setup_buf({ "###### Deep" })
  local content, _ = require("markview.parser").init(buf, 0, -1, false)

  local headings = vim.tbl_filter(function(n)
    return n.class == "markdown_atx_heading"
  end, content.markdown or {})

  expect.equality(#headings >= 1, true)
  expect.equality(#headings[1].marker, 6)
end

T["atx headings"]["node range is on row 0"] = function()
  local buf = H.setup_buf({ "# Title" })
  local content, _ = require("markview.parser").init(buf, 0, -1, false)

  local headings = vim.tbl_filter(function(n)
    return n.class == "markdown_atx_heading"
  end, content.markdown or {})

  expect.equality(headings[1].range.row_start, 0)
end

-- ── Fenced code blocks ────────────────────────────────────────────────────────

T["fenced code blocks"] = new_set()

T["fenced code blocks"]["produces markdown_code_block node"] = function()
  local buf = H.setup_buf({ "```lua", "print('hi')", "```" })
  local content, _ = require("markview.parser").init(buf, 0, -1, false)

  local blocks = vim.tbl_filter(function(n)
    return n.class == "markdown_code_block"
  end, content.markdown or {})

  expect.equality(#blocks >= 1, true)
end

T["fenced code blocks"]["language field is captured"] = function()
  local buf = H.setup_buf({ "```python", "pass", "```" })
  local content, _ = require("markview.parser").init(buf, 0, -1, false)

  local blocks = vim.tbl_filter(function(n)
    return n.class == "markdown_code_block"
  end, content.markdown or {})

  expect.equality(#blocks >= 1, true)
  -- language field should mention python (exact field name may vary)
  local info = blocks[1].language or blocks[1].lang or blocks[1].info_string or ""
  expect.equality(info:find("python") ~= nil, true)
end

-- ── Horizontal rules ──────────────────────────────────────────────────────────

T["horizontal rules"] = new_set()

T["horizontal rules"]["--- is parsed"] = function()
  local buf = H.setup_buf({ "---" })
  local content, _ = require("markview.parser").init(buf, 0, -1, false)

  local rules = vim.tbl_filter(function(n)
    return n.class == "markdown_hr" or n.class == "markdown_horizontal_rule"
  end, content.markdown or {})

  expect.equality(#rules >= 1, true)
end

-- ── Block quotes ──────────────────────────────────────────────────────────────

T["block quotes"] = new_set()

T["block quotes"]["produces a node"] = function()
  local buf = H.setup_buf({ "> a quote" })
  local content, _ = require("markview.parser").init(buf, 0, -1, false)

  local quotes = vim.tbl_filter(function(n)
    return n.class and n.class:find("block_quote") ~= nil
  end, content.markdown or {})

  expect.equality(#quotes >= 1, true)
end

-- ── Ordered lists ─────────────────────────────────────────────────────────────

T["lists"] = new_set()

T["lists"]["unordered list item is parsed"] = function()
  local buf = H.setup_buf({ "- item one", "- item two" })
  local content, _ = require("markview.parser").init(buf, 0, -1, false)

  local items = vim.tbl_filter(function(n)
    return n.class and n.class:find("list_item") ~= nil
  end, content.markdown or {})

  expect.equality(#items >= 2, true)
end

T["lists"]["ordered list item is parsed"] = function()
  local buf = H.setup_buf({ "1. first", "2. second" })
  local content, _ = require("markview.parser").init(buf, 0, -1, false)

  local items = vim.tbl_filter(function(n)
    return n.class and n.class:find("list_item") ~= nil
  end, content.markdown or {})

  expect.equality(#items >= 2, true)
end

-- ── Inline markdown ───────────────────────────────────────────────────────────

T["inline"] = new_set()

-- Bold/italic are styled via tree-sitter highlight groups only.
-- markview does NOT produce parsed nodes for bold/italic — this is intentional.
-- A heading followed by paragraph text DOES produce a section node.
T["inline"]["heading with text produces a section node"] = function()
  local buf = H.setup_buf({ "# Title", "", "paragraph with **bold** text" })
  local content, _ = require("markview.parser").init(buf, 0, -1, false)

  local sections = vim.tbl_filter(function(n)
    return n.class and n.class:find("section") ~= nil
  end, content.markdown or {})

  expect.equality(#sections >= 1, true)
end

T["inline"]["inline code span produces node"] = function()
  local buf = H.setup_buf({ "some `code` here" })
  local content, _ = require("markview.parser").init(buf, 0, -1, false)

  local codes = vim.tbl_filter(function(n)
    return n.class and n.class:find("code") ~= nil
  end, content.markdown_inline or {})

  expect.equality(#codes >= 1, true)
end

return T
