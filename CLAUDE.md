# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this plugin is

`markview.nvim` is a Neovim plugin that previews Markdown, HTML, LaTeX, Typst, AsciiDoc, and YAML files in-place using extmarks (virtual text + concealment). It supports hybrid editing mode (preview + edit simultaneously) and split-view mode.

## Testing

Automated test suite uses [mini.test](https://github.com/echasnovski/mini.test):

```bash
make test                        # run all tests
make test-file FILE=tests/test_renderer.lua  # run a single file
```

Test files live in `tests/`. When fixing a bug, add a regression test in `tests/test_fixes.lua` that would have caught it. Structure: one `new_set()` group per fix, named after the bug (e.g. `T["emoji fallback"]`).

Manual visual tests (rendering output):

```bash
nvim test/markdown.md
nvim test/markdown_inline.md
nvim test/typst.typ
nvim test/asciidoc.adoc
```

Health check:
```
:checkhealth markview
```

## Architecture

```
plugin/markview.lua          Entry point — sets up autocmds and commands
lua/markview.lua             Public API (setup, render, clear, strict_render)
lua/markview/
  spec.lua                   Config store + spec.get() accessor (single source of truth for config)
  state.lua                  Global runtime state (attached buffers, splitview windows, etc.)
  actions.lua                Core logic: hybrid mode detection, render/clear dispatch
  autocmds.lua               Autocommand setup (TextChanged, CursorMoved, BufEnter, etc.)
  commands.lua               :Markview sub-commands
  parser.lua                 Tree-sitter query orchestration → produces parsed node tables
  renderer.lua               Dispatch parsed nodes to per-filetype renderers + extmark management
  highlights.lua             Dynamic highlight group generation (derives colors from colorscheme)
  filetypes.lua              Language → icon/sign/hl mappings for code blocks
  symbols.lua                Unicode symbol lookup table
  entities.lua               HTML entity lookup table
  links.lua                  Link resolution helpers
  wrap.lua                   Line-wrap rendering helpers
  parsers/                   Per-language tree-sitter query files
  renderers/                 Per-language extmark renderers
    markdown.lua             Main markdown renderer (headings, tables, lists, code blocks…)
    markdown_inline.lua      Inline markdown (bold, italic, links, code spans…)
    markdown/tostring.lua    Markdown → plain-string converter (used for width calculations)
    asciidoc.lua / asciidoc_inline.lua
    comment.lua              Comment-embedded markdown
    html.lua / latex.lua / typst.lua / yaml.lua
  config/                    Default config sub-tables (one file per filetype)
  extras/                    Optional extra modules (blink-markview, cmp-markview)
  types/                     EmmyLua type definitions
```

### Data flow

1. `autocmds.lua` fires on buffer events → calls `actions.render(buf)` or `actions.clear(buf)`
2. `actions.render` reads config via `spec.get()`, checks hybrid/preview mode, then calls `parser.parse(buf)`
3. `parser.lua` runs tree-sitter queries for all relevant languages, returns a typed table of nodes
4. `renderer.render(buf, parsed)` maps each node type to its renderer function via `renderer.option_maps`
5. Renderer functions call `vim.api.nvim_buf_set_extmark()` directly to place virtual text / conceal marks

### Key conventions

- **`spec.get(path, opts)`** is the canonical way to read config anywhere. Never read `require("markview.spec").default` directly.
- **`---|fS` / `---|fE`** markers are fold markers used throughout — don't remove them.
- Renderer functions receive a parsed node and return nothing; they apply extmarks as a side effect.
- `renderer.option_maps` maps config keys → node type names, enabling enable/disable per feature.
- `state.vars` is the single runtime state object. Access through `require("markview.state")`.

## Lua style

Follow the project-wide EmmyLua annotation rules (see `.claude/rules/lua-style.md`):
- Annotate all function params with `@param`, returns with `@return`
- Use `@class` + `@field` for shared structured tables
- LSP config is in `.luarc.json`; `vim` is declared as a known global there

## Commits

Follow Conventional Commits: `fix(scope):`, `feat(scope):`, `chore(scope):`, `doc:`.
