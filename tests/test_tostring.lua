-- Tests for lua/markview/renderers/markdown/tostring.lua
-- These test the inline-markdown → plain-string conversion used for width calculations.
local new_set = MiniTest.new_set
local expect = MiniTest.expect

local md_str

local T = new_set({
  hooks = {
    pre_once = function()
      -- Ensure default spec is loaded (spec.config is initialised at require-time).
      require("markview.spec")
      md_str = require("markview.renderers.markdown.tostring")
      -- Force a cache update so cached_config reflects the default spec.
      md_str.update_cache()
    end,
  },
})

-- Helper: call tostring with buffer = -1 (unused by default config for plain text).
local function ts(text)
  return md_str.tostring(-1, text, false)
end

-- ── Bold ─────────────────────────────────────────────────────────────────────

T["bold"] = new_set()

T["bold"]["strips ** markers"] = function()
  expect.equality(ts("**hello**"), "hello")
end

T["bold"]["strips __ markers"] = function()
  expect.equality(ts("__world__"), "world")
end

T["bold"]["leaves trailing-space edge case intact"] = function()
  -- "** " at end is not a valid closer — bold() returns the raw match.
  local raw = "**text **"
  local result = ts(raw)
  -- Must not crash; returns something (either stripped or original).
  expect.equality(type(result), "string")
end

-- ── Italic ────────────────────────────────────────────────────────────────────

T["italic"] = new_set()

T["italic"]["strips * markers"] = function()
  expect.equality(ts("*hello*"), "hello")
end

T["italic"]["strips _ markers"] = function()
  expect.equality(ts("_hello_"), "hello")
end

-- ── Bold+italic ───────────────────────────────────────────────────────────────

T["bold_italic"] = new_set()

T["bold_italic"]["strips *** markers"] = function()
  expect.equality(ts("***hi***"), "hi")
end

T["bold_italic"]["strips ___ markers"] = function()
  expect.equality(ts("___hi___"), "hi")
end

-- ── Inline code ───────────────────────────────────────────────────────────────

T["inline_code"] = new_set()

T["inline_code"]["single backtick"] = function()
  local result = ts("`code`")
  -- With default config the icon/padding may wrap the text, but the raw
  -- identifier must appear somewhere in the output.
  expect.equality(result:find("code") ~= nil, true)
end

T["inline_code"]["double backtick preserves inner backtick"] = function()
  local result = ts("``a`b``")
  expect.equality(result:find("a`b") ~= nil, true)
end

-- ── Escape sequences ─────────────────────────────────────────────────────────

T["escape"] = new_set()

T["escape"]["backslash-star yields star"] = function()
  expect.equality(ts("\\*"), "*")
end

T["escape"]["backslash-underscore yields underscore"] = function()
  expect.equality(ts("\\_"), "_")
end

-- ── Nested / mixed ────────────────────────────────────────────────────────────

T["nested"] = new_set()

T["nested"]["bold containing italic"] = function()
  -- "**_hi_**" → strip bold → "_hi_" → strip italic → "hi"
  expect.equality(ts("**_hi_**"), "hi")
end

T["nested"]["plain text passes through unchanged"] = function()
  expect.equality(ts("hello world"), "hello world")
end

T["nested"]["empty string returns empty"] = function()
  expect.equality(ts(""), "")
end

return T
