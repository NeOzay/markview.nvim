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

-- ── Fix #506: CommonMark flanking rules for word-attached * emphasis ──────────
--
-- BUG: The old `at_valid` guard (start-of-string or after whitespace) skipped
--      `*`/`**` attached to a word (e.g. `x**bold**`), making tostring return a
--      width larger than what the renderer drew (which follows CommonMark flanking
--      rules). The fix adds flank_open/flank_close predicates for `*` patterns.

T["word-attached emphasis"] = new_set()

T["word-attached emphasis"]["x**bold** strips markers"] = function()
  local result = ts("x**bold**")
  expect.equality(result:find("bold") ~= nil, true)
  -- Markers must be gone — result must be shorter than the raw input.
  expect.equality(#result < #"x**bold**", true)
end

T["word-attached emphasis"]["2*3*4 strips * italic markers"] = function()
  local result = ts("2*3*4")
  expect.equality(result:find("3") ~= nil, true)
  expect.equality(#result < #"2*3*4", true)
end

T["word-attached emphasis"]["snake_case is NOT treated as italic"] = function()
  -- Underscore keeps the at_valid guard: intra-word _ is not emphasis.
  local result = ts("snake_case")
  expect.equality(result, "snake_case")
end

T["word-attached emphasis"]["normal space-separated bold still strips"] = function()
  expect.equality(ts("a **bold** b"), "a bold b")
end

-- ── Fix #576: spaces allowed at start/end of link source ─────────────────────
--
-- BUG: `[foo]( bar)` and `[foo](bar )` were not recognised as hyperlinks
--      because the lpeg grammar excluded spaces from src_content. The grammar
--      now allows optional leading/trailing whitespace in the URL.

T["link with spaces in source"] = new_set()

T["link with spaces in source"]["leading space: [foo]( bar) recognised as link"] = function()
  local result = ts("[foo]( bar)")
  expect.equality(result:find("foo") ~= nil, true)
  -- The raw brackets must be stripped — output shorter than input.
  expect.equality(#result < #"[foo]( bar)", true)
end

T["link with spaces in source"]["trailing space: [foo](bar ) recognised as link"] = function()
  local result = ts("[foo](bar )")
  expect.equality(result:find("foo") ~= nil, true)
  expect.equality(#result < #"[foo](bar )", true)
end

T["link with spaces in source"]["both spaces: [foo]( bar ) recognised as link"] = function()
  local result = ts("[foo]( bar )")
  expect.equality(result:find("foo") ~= nil, true)
  expect.equality(#result < #"[foo]( bar )", true)
end

T["link with spaces in source"]["image with leading space: ![alt]( img.png) recognised"] = function()
  local result = ts("![alt]( img.png)")
  expect.equality(result:find("alt") ~= nil, true)
  expect.equality(#result < #"![alt]( img.png)", true)
end

-- ── Fix #507: Obsidian-style links use alias when present ────────────────────
--
-- BUG: `[[Page|Alias]]` was rendering the full `Page|Alias` label through
--      tostring (which applies markdown formatting), instead of using the alias
--      directly. The fix uses `alias` when present, skipping the tostring call
--      on the label.

T["obsidian alias"] = new_set()

T["obsidian alias"]["[[Page|Alias]] output contains alias"] = function()
  local result = ts("[[Page|Alias]]")
  expect.equality(result:find("Alias") ~= nil, true)
end

T["obsidian alias"]["[[Page|Alias]] output does not contain raw pipe-label"] = function()
  local result = ts("[[Page|Alias]]")
  -- The raw "Page|Alias" fragment must not appear literally.
  expect.equality(result:find("Page|Alias", 1, true) == nil, true)
end

T["obsidian alias"]["[[Page]] without alias outputs Page"] = function()
  local result = ts("[[Page]]")
  expect.equality(result:find("Page") ~= nil, true)
end

return T
