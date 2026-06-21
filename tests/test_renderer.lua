-- Regression tests for markdown rendering (extmark output).
-- Strategy: parse + render known markdown, then assert on extmark structure.
-- We test positions, conceal chars, and virt_text content — NOT highlight
-- group names (those change with colorschemes and won't cause regressions).
local new_set = MiniTest.new_set
local expect = MiniTest.expect

local H = require("tests.helpers")

local T = new_set({
  hooks = {
    pre_once = function()
      -- Ensure default config is active.
      require("markview.spec")
    end,
    post_case = function()
      vim.cmd("%bwipeout!")
    end,
  },
})

-- ── Headings ─────────────────────────────────────────────────────────────────

T["headings"] = new_set()

T["headings"]["h1 places at least one extmark on row 0"] = function()
  local buf = H.setup_buf({ "# Hello" })
  H.render(buf)

  local marks = H.get_extmarks(buf, "markview/markdown")
  local on_row0 = vim.tbl_filter(function(m)
    return m[2] == 0
  end, marks)

  expect.equality(#on_row0 >= 1, true)
end

T["headings"]["h1 has line highlight on row 0"] = function()
  local buf = H.setup_buf({ "# Hello" })
  H.render(buf)

  local marks = H.get_extmarks(buf, "markview/markdown")
  local has_line_hl = false
  for _, m in ipairs(marks) do
    if m[2] == 0 and m[4] and m[4].line_hl_group then
      has_line_hl = true
      break
    end
  end

  expect.equality(has_line_hl, true)
end

T["headings"]["multiple headings each get a line highlight"] = function()
  local buf = H.setup_buf({ "# One", "", "## Two", "", "### Three" })
  H.render(buf)

  local marks = H.get_extmarks(buf, "markview/markdown")
  local rows_with_line_hl = {}
  for _, m in ipairs(marks) do
    if m[4] and m[4].line_hl_group then
      rows_with_line_hl[m[2]] = true
    end
  end

  -- Rows 0, 2, 4 should all have line highlights.
  expect.equality(rows_with_line_hl[0], true)
  expect.equality(rows_with_line_hl[2], true)
  expect.equality(rows_with_line_hl[4], true)
end

T["headings"]["h1 conceals the # marker"] = function()
  local buf = H.setup_buf({ "# Title" })
  H.render(buf)

  local marks = H.get_extmarks(buf, "markview/markdown")
  -- There should be a conceal extmark on row 0 that hides the "#" sign.
  local conceal_marks = H.conceal_at(marks, 0)
  expect.equality(#conceal_marks >= 1, true)
end

-- ── Fenced code blocks ────────────────────────────────────────────────────────

T["code blocks"] = new_set()

T["code blocks"]["fence lines get extmarks"] = function()
  local buf = H.setup_buf({ "```lua", "local x = 1", "```" })
  H.render(buf)

  local marks = H.get_extmarks(buf, "markview/markdown")
  -- At minimum the opening (row 0) and closing (row 2) fences should be marked.
  local rows = {}
  for _, m in ipairs(marks) do
    rows[m[2]] = true
  end

  expect.equality(rows[0] ~= nil, true)
  expect.equality(rows[2] ~= nil, true)
end

T["code blocks"]["opening fence is concealed"] = function()
  local buf = H.setup_buf({ "```lua", "local x = 1", "```" })
  H.render(buf)

  local marks = H.get_extmarks(buf, "markview/markdown")
  local conceal = H.conceal_at(marks, 0)
  expect.equality(#conceal >= 1, true)
end

T["code blocks"]["closing fence is concealed"] = function()
  local buf = H.setup_buf({ "```", "code", "```" })
  H.render(buf)

  local marks = H.get_extmarks(buf, "markview/markdown")
  local conceal = H.conceal_at(marks, 2)
  expect.equality(#conceal >= 1, true)
end

T["code blocks"]["body row has exactly a line highlight (background only)"] = function()
  -- The body of a code block gets a line_hl_group for the background colour,
  -- but NOT a conceal or virt_text extmark.
  local buf = H.setup_buf({ "```", "plain text body", "```" })
  H.render(buf)

  local marks = H.get_extmarks(buf, "markview/markdown")
  local on_body = vim.tbl_filter(function(m)
    return m[2] == 1
  end, marks)

  -- Exactly one extmark on the body: the line_hl background.
  expect.equality(#on_body, 1)
  expect.equality(on_body[1][4].line_hl_group ~= nil, true)
  expect.equality(on_body[1][4].conceal, nil)
  expect.equality(on_body[1][4].virt_text, nil)
end

-- ── Horizontal rules ──────────────────────────────────────────────────────────

T["horizontal rules"] = new_set()

T["horizontal rules"]["--- produces virt_text or conceal on row 0"] = function()
  local buf = H.setup_buf({ "---" })
  H.render(buf)

  local marks = H.get_extmarks(buf, "markview/markdown")
  local row0 = vim.tbl_filter(function(m)
    return m[2] == 0
  end, marks)

  -- A horizontal rule must produce at least one extmark on its row.
  expect.equality(#row0 >= 1, true)
end

-- ── Block quotes ──────────────────────────────────────────────────────────────

T["block quotes"] = new_set()

T["block quotes"]["produces extmark on the quote row"] = function()
  local buf = H.setup_buf({ "> a quote" })
  H.render(buf)

  local marks = H.get_extmarks(buf, "markview/markdown")
  local row0 = vim.tbl_filter(function(m)
    return m[2] == 0
  end, marks)

  expect.equality(#row0 >= 1, true)
end

-- ── Inline code span ─────────────────────────────────────────────────────────
-- Bold/italic markers are styled via tree-sitter highlight groups only —
-- markview does not place extmarks for them. Code spans ARE rendered.

T["inline code span"] = new_set()

T["inline code span"]["produces extmarks on its row"] = function()
  local buf = H.setup_buf({ "some `code` here" })
  H.render(buf)

  local marks = H.get_extmarks(buf, "markview/inline")
  local row0 = vim.tbl_filter(function(m)
    return m[2] == 0
  end, marks)

  expect.equality(#row0 >= 1, true)
end

T["inline code span"]["backtick markers are concealed"] = function()
  local buf = H.setup_buf({ "some `code` here" })
  H.render(buf)

  local marks = H.get_extmarks(buf, "markview/inline")
  local conceal = H.conceal_at(marks, 0)
  expect.equality(#conceal >= 2, true) -- opening + closing backtick
end

-- ── List items ────────────────────────────────────────────────────────────────

T["list items"] = new_set()

T["list items"]["unordered marker gets an extmark"] = function()
  local buf = H.setup_buf({ "- item" })
  H.render(buf)

  local marks = H.get_extmarks(buf, "markview/markdown")
  local row0 = vim.tbl_filter(function(m)
    return m[2] == 0
  end, marks)

  expect.equality(#row0 >= 1, true)
end

T["list items"]["ordered marker gets an extmark"] = function()
  local buf = H.setup_buf({ "1. item" })
  H.render(buf)

  local marks = H.get_extmarks(buf, "markview/markdown")
  local row0 = vim.tbl_filter(function(m)
    return m[2] == 0
  end, marks)

  expect.equality(#row0 >= 1, true)
end

-- ── Extmark count regression ──────────────────────────────────────────────────
-- These tests catch unexpected changes in the number of extmarks produced.
-- If any of these fail after a change, you should verify the rendering
-- is correct visually before updating the expected count.

T["extmark count"] = new_set()

T["extmark count"]["plain paragraph produces no extmarks"] = function()
  local buf = H.setup_buf({ "Just a plain paragraph." })
  H.render(buf)

  local marks = H.all_extmarks(buf)
  expect.equality(#marks, 0)
end

T["extmark count"]["h1 produces exactly 1 extmark (icon+line_hl combined)"] = function()
  -- With the default "icon" style, heading rendering uses a single extmark
  -- that carries both line_hl_group and virt_text. If this breaks, the
  -- heading is being split into multiple marks or rendered differently.
  local buf = H.setup_buf({ "# Title" })
  H.render(buf)

  local marks = H.get_extmarks(buf, "markview/markdown")
  expect.equality(#marks, 1)
  -- That single mark must have both a line highlight and virtual text.
  expect.equality(marks[1][4].line_hl_group ~= nil, true)
  expect.equality(marks[1][4].virt_text ~= nil, true)
end

return T
