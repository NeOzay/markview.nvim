-- Tests for block-level renderer functions not covered by test_renderer.lua:
-- setext_heading, indented_code_block, metadata_minus, metadata_plus,
-- link_ref_definition, checkbox
local new_set = MiniTest.new_set
local expect = MiniTest.expect

local H = require("tests.helpers")

local T = new_set({
  hooks = {
    pre_once = function()
      require("markview.spec")
    end,
    post_case = function()
      vim.cmd("silent %bwipeout!")
    end,
  },
})

-- ── setext_heading ────────────────────────────────────────────────────────────

T["setext_heading"] = new_set()

T["setext_heading"]["=== underline produces extmark on heading row"] = function()
  local buf = H.setup_buf({ "My Heading", "==========" })
  H.render(buf)
  local marks = H.get_extmarks(buf, "markview/markdown")
  local on_row0 = vim.tbl_filter(function(m) return m[2] == 0 end, marks)
  expect.equality(#on_row0 >= 1, true)
end

T["setext_heading"]["--- underline produces extmark on heading row"] = function()
  local buf = H.setup_buf({ "Subheading", "----------" })
  H.render(buf)
  local marks = H.get_extmarks(buf, "markview/markdown")
  local on_row0 = vim.tbl_filter(function(m) return m[2] == 0 end, marks)
  expect.equality(#on_row0 >= 1, true)
end

T["setext_heading"]["underline row receives a decoration"] = function()
  local buf = H.setup_buf({ "Heading", "=======" })
  H.render(buf)
  local marks = H.get_extmarks(buf, "markview/markdown")
  local on_row1 = vim.tbl_filter(function(m) return m[2] == 1 end, marks)
  local decorated = vim.tbl_filter(function(m)
    local o = m[4]
    return o.line_hl_group ~= nil
      or (o.virt_text ~= nil and o.virt_text_pos == "overlay")
      or o.conceal ~= nil
  end, on_row1)
  expect.equality(#decorated >= 1, true)
end

-- ── indented_code_block ───────────────────────────────────────────────────────

T["indented_code_block"] = new_set()

T["indented_code_block"]["4-space indent produces at least one extmark"] = function()
  local buf = H.setup_buf({ "    print('hello')" })
  H.render(buf)
  local marks = H.get_extmarks(buf, "markview/markdown")
  expect.equality(#marks >= 1, true)
end

T["indented_code_block"]["code line has a line_hl_group"] = function()
  local buf = H.setup_buf({ "    code here" })
  H.render(buf)
  local marks = H.get_extmarks(buf, "markview/markdown")
  local with_hl = vim.tbl_filter(function(m)
    return m[4].line_hl_group ~= nil
  end, marks)
  expect.equality(#with_hl >= 1, true)
end

-- ── metadata_minus ────────────────────────────────────────────────────────────
-- metadata_minus uses nvim_win_get_width, so the buffer must have a window.

T["metadata_minus"] = new_set()

T["metadata_minus"]["--- block produces extmark on opening delimiter row"] = function()
  local buf, win = H.setup_windowed_buf({ "---", "key: value", "---" })
  H.render(buf)
  local marks = H.get_extmarks(buf, "markview/markdown")
  vim.api.nvim_win_close(win, true)
  local on_row0 = vim.tbl_filter(function(m) return m[2] == 0 end, marks)
  expect.equality(#on_row0 >= 1, true)
end

T["metadata_minus"]["closing delimiter row also gets an extmark"] = function()
  local buf, win = H.setup_windowed_buf({ "---", "key: value", "---" })
  H.render(buf)
  local marks = H.get_extmarks(buf, "markview/markdown")
  vim.api.nvim_win_close(win, true)
  local on_row2 = vim.tbl_filter(function(m) return m[2] == 2 end, marks)
  expect.equality(#on_row2 >= 1, true)
end

T["metadata_minus"]["inner lines have line_hl_group"] = function()
  local buf, win = H.setup_windowed_buf({ "---", "title: test", "date: 2024", "---" })
  H.render(buf)
  local marks = H.get_extmarks(buf, "markview/markdown")
  vim.api.nvim_win_close(win, true)
  local inner_hl = vim.tbl_filter(function(m)
    return (m[2] == 1 or m[2] == 2) and m[4].line_hl_group ~= nil
  end, marks)
  expect.equality(#inner_hl >= 1, true)
end

-- ── metadata_plus ─────────────────────────────────────────────────────────────

T["metadata_plus"] = new_set()

T["metadata_plus"]["rendering +++ block produces no errors"] = function()
  local buf, win = H.setup_windowed_buf({ "+++", "key = 'value'", "+++" })
  expect.no_error(function() H.render(buf) end)
  vim.api.nvim_win_close(win, true)
end

T["metadata_plus"]["if +++ is parsed it produces extmarks on opening row"] = function()
  local buf, win = H.setup_windowed_buf({ "+++", "key = 'value'", "+++" })
  H.render(buf)
  local marks = H.get_extmarks(buf, "markview/markdown")
  vim.api.nvim_win_close(win, true)
  -- TOML front matter support depends on the installed grammar version;
  -- we only assert that if marks exist they land on the right rows.
  if #marks > 0 then
    local on_row0 = vim.tbl_filter(function(m) return m[2] == 0 end, marks)
    expect.equality(#on_row0 >= 1, true)
  end
end

-- ── link_ref_definition ───────────────────────────────────────────────────────

T["link_ref_definition"] = new_set()

T["link_ref_definition"]["produces extmark on label row"] = function()
  local buf = H.setup_buf({ "[label]: https://example.com" })
  H.render(buf)
  local marks = H.get_extmarks(buf, "markview/markdown")
  local on_row0 = vim.tbl_filter(function(m) return m[2] == 0 end, marks)
  expect.equality(#on_row0 >= 1, true)
end

T["link_ref_definition"]["label has conceal or virt_text decoration"] = function()
  local buf = H.setup_buf({ "[mylabel]: https://example.com" })
  H.render(buf)
  local marks = H.get_extmarks(buf, "markview/markdown")
  local decorated = vim.tbl_filter(function(m)
    return m[2] == 0 and (m[4].conceal ~= nil or m[4].virt_text ~= nil)
  end, marks)
  expect.equality(#decorated >= 1, true)
end

-- ── checkbox ─────────────────────────────────────────────────────────────────

T["checkbox"] = new_set()

T["checkbox"]["unchecked [ ] produces extmark on its row"] = function()
  local buf = H.setup_buf({ "- [ ] unchecked item" })
  H.render(buf)
  local marks = H.all_extmarks(buf)
  local on_row0 = vim.tbl_filter(function(m) return m.row == 0 end, marks)
  expect.equality(#on_row0 >= 1, true)
end

T["checkbox"]["checked [x] produces extmark on its row"] = function()
  local buf = H.setup_buf({ "- [x] checked item" })
  H.render(buf)
  local marks = H.all_extmarks(buf)
  local on_row0 = vim.tbl_filter(function(m) return m.row == 0 end, marks)
  expect.equality(#on_row0 >= 1, true)
end

T["checkbox"]["checked and unchecked produce different virt_text content"] = function()
  local buf_unchecked = H.setup_buf({ "- [ ] unchecked" })
  H.render(buf_unchecked)

  local buf_checked = H.setup_buf({ "- [x] checked" })
  H.render(buf_checked)

  local vt_unchecked = H.virt_text_at(H.all_extmarks(buf_unchecked), 0)
  local vt_checked = H.virt_text_at(H.all_extmarks(buf_checked), 0)

  -- at least one of the two buffers must have virt_text (checkbox rendering active)
  expect.equality(#vt_unchecked + #vt_checked >= 1, true)
  -- the two sets must differ (different state → different icon)
  expect.no_equality(vt_unchecked, vt_checked)
end

return T
