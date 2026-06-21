---@class markview.test.helpers
local H = {}

--- Create a scratch markdown buffer with the given lines.
--- Also starts tree-sitter parsing (required in headless mode).
---@param lines string[]
---@return integer buf
function H.setup_buf(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "markdown"
  -- filetype alone doesn't start TS in headless; do it explicitly.
  vim.treesitter.start(buf, "markdown")
  return buf
end

--- Parse + render a buffer through the markview pipeline.
--- Returns the flat parsed content table.
---@param buf integer
---@return table content
function H.render(buf)
  local content, _ = require("markview.parser").init(buf, 0, -1, false)
  require("markview.renderer").render(buf, content)
  return content
end

--- Create a scratch markdown buffer with an associated floating window.
--- Required for elements whose renderer checks for a window (tables, etc.).
--- Returns both the buffer and the window; caller must close the window in post_case.
---@param lines string[]
---@return integer buf, integer win
function H.setup_windowed_buf(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "markdown"
  vim.treesitter.start(buf, "markdown")
  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = 80,
    height = math.max(#lines + 4, 10),
    row = 0,
    col = 0,
  })
  vim.wo[win].wrap = false
  return buf, win
end

--- Get all extmarks placed by a markview namespace on a buffer.
---@param buf integer
---@param ns_name string  e.g. "markview/markdown"
---@return table[] marks  each: { id, row, col, opts }
function H.get_extmarks(buf, ns_name)
  local ns_id = vim.api.nvim_get_namespaces()[ns_name]
  if not ns_id then
    return {}
  end
  return vim.api.nvim_buf_get_extmarks(buf, ns_id, { 0, 0 }, { -1, -1 }, { details = true })
end

--- Get all extmarks from every markview namespace on a buffer.
---@param buf integer
---@return table[] marks  each: { ns, id, row, col, opts }
function H.all_extmarks(buf)
  local result = {}
  for name, ns_id in pairs(vim.api.nvim_get_namespaces()) do
    if name:match("^markview") then
      local marks = vim.api.nvim_buf_get_extmarks(buf, ns_id, { 0, 0 }, { -1, -1 }, { details = true })
      for _, m in ipairs(marks) do
        table.insert(result, { ns = name, id = m[1], row = m[2], col = m[3], opts = m[4] })
      end
    end
  end
  return result
end

--- Return only the extmarks that have a conceal field on a given row.
---@param marks table[]  output of H.get_extmarks or H.all_extmarks
---@param row integer     0-indexed
---@return table[]
function H.conceal_at(marks, row)
  local out = {}
  for _, m in ipairs(marks) do
    local r = m[2] or m.row
    local opts = m[4] or m.opts or {}
    if r == row and opts.conceal ~= nil then
      table.insert(out, m)
    end
  end
  return out
end

--- Extract virt_text strings (ignore highlight groups) from extmarks on a row.
---@param marks table[]
---@param row integer  0-indexed
---@return string[]
function H.virt_text_at(marks, row)
  local out = {}
  for _, m in ipairs(marks) do
    local r = m[2] or m.row
    local opts = m[4] or m.opts or {}
    if r == row and opts.virt_text then
      for _, chunk in ipairs(opts.virt_text) do
        table.insert(out, chunk[1])
      end
    end
  end
  return out
end

return H
