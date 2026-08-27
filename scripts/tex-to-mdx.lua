-- Pandoc filter: IEEEtran LaTeX -> MDX-safe GFM for the vphilox site.
--
-- Does four things pandoc's latex reader cannot:
--   1. numbers sections, figures, tables, equations and the algorithm, then
--      rewrites every \cref into "Section 3.2" / "Table 4" / "Equation (2)";
--   2. turns \cite{key} into a numbered link into the reference list;
--   3. rebuilds thebibliography, whose \bibitem keys pandoc discards, by
--      zipping the surviving paragraphs against the key order in the .tex;
--   4. strips \label{} out of math, which KaTeX rejects.
--
-- Output targets gfm, so nothing may rely on pandoc's `{#id}` attribute
-- syntax -- MDX reads a brace as the start of a JS expression. Anywhere an
-- id is needed, this emits raw HTML instead.

local bibkeys = {}        -- ordered list of \bibitem keys
local bibnum  = {}        -- key -> reference number
local num     = {}        -- label -> rendered number ("3.2", "4", ...)
local kindof  = {}        -- label -> "sec" | "fig" | "tab" | "eq" | "alg"

local counters = { sec = { 0, 0, 0 }, fig = 0, tab = 0, eq = 0, alg = 0 }

local NAMES = {
  sec = { one = 'Section',  many = 'Sections',   paren = false },
  fig = { one = 'Figure',   many = 'Figures',    paren = false },
  tab = { one = 'Table',    many = 'Tables',     paren = false },
  eq  = { one = 'Equation', many = 'Equations',  paren = true  },
  alg = { one = 'Algorithm',many = 'Algorithms', paren = false },
}

local function kind_of(label)
  return label:match('^([a-z]+):')
end

-- ---------------------------------------------------------------- pass 1

local function section_number(level)
  if level > 3 then level = 3 end
  counters.sec[level] = counters.sec[level] + 1
  for i = level + 1, 3 do counters.sec[i] = 0 end
  local parts = {}
  for i = 1, level do parts[#parts + 1] = tostring(counters.sec[i]) end
  return table.concat(parts, '.')
end

local function bump(kind)
  counters[kind] = counters[kind] + 1
  return tostring(counters[kind])
end

local function record(label, value)
  if label and label ~= '' then
    num[label] = value
    kindof[label] = kind_of(label)
  end
end

-- Equation labels live inside the math string as \label{eq:foo}. A single
-- align environment carries several, and each numbered line gets its own.
local function scan_math_labels(s)
  for label in s:gmatch('\\label{(eq:[^}]+)}') do
    record(label, bump('eq'))
  end
end

local function collect(blocks)
  for _, b in ipairs(blocks) do
    if b.t == 'Header' then
      if not b.classes:includes('unnumbered') then
        local n = section_number(b.level)
        record(b.identifier, n)
        b.attributes['data-number'] = n
      end
    elseif b.t == 'Div' then
      if b.classes:includes('algorithm') then
        record(b.identifier ~= '' and b.identifier or 'alg:contract', bump('alg'))
      elseif b.identifier:match('^tab:') then
        record(b.identifier, bump('tab'))
      end
      collect(b.content)
    elseif b.t == 'Figure' then
      record(b.identifier, bump('fig'))
    elseif b.t == 'Table' then
      -- a table pandoc left outside a Div
      if b.identifier and b.identifier:match('^tab:') then
        record(b.identifier, bump('tab'))
      end
    elseif b.t == 'Para' or b.t == 'Plain' then
      for _, i in ipairs(b.content) do
        if i.t == 'Image' and i.identifier:match('^fig:') then
          record(i.identifier, bump('fig'))
        elseif i.t == 'Math' then
          scan_math_labels(i.text)
        end
      end
    end
  end
end

-- ---------------------------------------------------------------- pass 2

-- \cref renders as a Link whose target is "#a:1,b:2" for a multi-reference.
local function render_ref(target)
  local labels = {}
  for label in target:gmatch('[^,#]+') do labels[#labels + 1] = label end
  if #labels == 0 then return nil end

  local kind = kind_of(labels[1])
  local name = NAMES[kind]
  if not name then return nil end

  local out = {}
  out[#out + 1] = pandoc.Str((#labels > 1 and name.many or name.one))
  out[#out + 1] = pandoc.Space()

  for i, label in ipairs(labels) do
    if i > 1 then
      out[#out + 1] = (i == #labels) and pandoc.Str(' and ') or pandoc.Str(', ')
    end
    local n = num[label] or '?'
    local text = name.paren and ('(' .. n .. ')') or n
    out[#out + 1] = pandoc.Link(pandoc.Str(text), '#' .. label)
  end
  return out
end

local function Link(el)
  local t = el.target
  -- pandoc writes <url> when the link text equals the target; MDX reads that
  -- as the start of a JSX tag, so force the explicit [text](url) form
  if t:match('^%a[%w+.-]*:') and pandoc.utils.stringify(el.content) == t then
    return pandoc.RawInline('gfm', '[' .. t .. '](' .. t .. ')')
  end
  if t:sub(1, 1) == '#' then
    local rendered = render_ref(t)
    if rendered then return rendered end
    -- plain internal link: drop pandoc's reference-type attributes
    return pandoc.Link(el.content, t)
  end
  return nil
end

local function Cite(el)
  local out = { pandoc.Str('[') }
  for i, c in ipairs(el.citations) do
    if i > 1 then out[#out + 1] = pandoc.Str(', ') end
    local n = bibnum[c.id]
    out[#out + 1] = n
      and pandoc.Link(pandoc.Str(tostring(n)), '#ref-' .. c.id)
      or pandoc.Str('?')
  end
  out[#out + 1] = pandoc.Str(']')
  return out
end

-- The gfm writer emits $`x`$ for inline math and a bare fence for display
-- math; remark-math parses neither. Emit the markdown verbatim instead, and
-- give each \label{eq:...} an anchor so cross-references have a target.
local function Math(el)
  local labels = {}
  for label in el.text:gmatch('\\label{(eq:[^}]+)}') do
    labels[#labels + 1] = label
  end
  local text = el.text:gsub('%s*\\label{[^}]*}', '')

  if el.mathtype == 'DisplayMath' then
    local anchors, nums = {}, {}
    for _, l in ipairs(labels) do
      anchors[#anchors + 1] = '<span class="eq-anchor" id="' .. l .. '"></span>'
      nums[#nums + 1] = '(' .. (num[l] or '?') .. ')'
    end
    local tag = #nums > 0
      and ('<span class="eqno">' .. table.concat(nums, ' ') .. '</span>')
      or ''
    -- MDX only allows markdown children inside a JSX element when the tags
    -- sit on their own lines, so every part gets its own block
    return pandoc.RawInline('gfm',
      '\n\n<div class="equation">\n' .. table.concat(anchors, '\n') ..
      (tag ~= '' and ('\n' .. tag) or '') ..
      '\n\n$$\n' .. text .. '\n$$\n\n</div>\n\n')
  end

  return pandoc.RawInline('gfm', '$' .. text .. '$')
end

-- MDX does not support indented code blocks; a language class forces pandoc
-- to write a fence instead.
local function CodeBlock(el)
  if #el.classes == 0 then
    el.classes = pandoc.List({ 'text' })
  end
  return el
end

local function Image(el)
  -- figures are staged next to the MDX; './' makes Astro treat them as
  -- local assets rather than as public/ paths
  el.src = './' .. el.src:gsub('.*/', ''):gsub('%.pdf$', '.svg')
  return el
end

-- ---------------------------------------------------------------- blocks

local function html(s) return pandoc.RawBlock('html', s) end

-- A caption rendered as a single paragraph: "Figure 3. <caption text>".
-- Keeping it one block matters, because MDX only allows markdown children
-- inside a JSX element when the tags sit alone on their own lines.
local function caption_block(kindname, n, blocks)
  local inlines = pandoc.List({
    pandoc.RawInline('gfm', '<span class="label">' .. kindname .. ' ' .. n .. '.</span> '),
  })
  inlines:extend(pandoc.utils.blocks_to_inlines(blocks, { pandoc.Space() }))
  return pandoc.Plain(inlines)
end

local function Div(el)
  -- the reference list: pandoc kept the entries but lost every key
  if el.classes:includes('thebibliography') then
    local out = { html('<ol class="references">') }
    local n = 0
    for _, b in ipairs(el.content) do
      if b.t == 'Para' or b.t == 'Plain' then
        -- the first Para is thebibliography's widest-label argument ("10")
        if n == 0 and #b.content == 1 and b.content[1].t == 'Span' then
          goto continue
        end
        n = n + 1
        local key = bibkeys[n] or ('entry' .. n)
        out[#out + 1] = html('<li id="ref-' .. key .. '">')
        out[#out + 1] = pandoc.Plain(b.content)
        out[#out + 1] = html('</li>')
      end
      ::continue::
    end
    out[#out + 1] = html('</ol>')
    return out
  end

  -- algorithm2e bodies do not survive; leave a marker to fill in by hand
  -- algorithm2e bodies do not survive pandoc at all, so the markup is kept by
  -- hand in _algorithm.mdx.part and spliced in here.
  if el.classes:includes('algorithm') then
    local f = io.open('src/content/paper/_algorithm.mdx.part', 'r')
    if not f then
      return html('{/* missing src/content/paper/_algorithm.mdx.part */}')
    end
    local body = f:read('a')
    f:close()
    return pandoc.RawBlock('gfm', body)
  end

  -- a captioned table: emit <figure> so the caption can be styled and linked
  if el.identifier:match('^tab:') then
    local n = num[el.identifier] or '?'
    local out = { html('<figure id="' .. el.identifier .. '" class="table-figure">') }
    for _, b in ipairs(el.content) do
      if b.t == 'Table' then
        local cap = b.caption.long
        b.caption = pandoc.Caption({})
        out[#out + 1] = b
        out[#out + 1] = html('<figcaption>')
        out[#out + 1] = caption_block('Table', n, cap)
        out[#out + 1] = html('</figcaption>')
      else
        out[#out + 1] = b
      end
    end
    out[#out + 1] = html('</figure>')
    return out
  end

  if el.identifier == '' and #el.classes == 0 then return el.content end
  return nil
end

-- pandoc 3 lifts \begin{figure} into a Figure block of its own.
local function Figure(el)
  local n = num[el.identifier] or '?'
  local out = { html('<figure id="' .. el.identifier .. '">') }
  for _, b in ipairs(el.content) do out[#out + 1] = b end
  out[#out + 1] = html('<figcaption>')
  out[#out + 1] = caption_block('Figure', n, el.caption.long)
  out[#out + 1] = html('</figcaption>')
  out[#out + 1] = html('</figure>')
  return out
end

-- A standalone image paragraph becomes a numbered <figure>.
local function Para(el)
  if #el.content == 1 and el.content[1].t == 'Image' then
    local img = el.content[1]
    if img.identifier:match('^fig:') then
      local n = num[img.identifier] or '?'
      local out = {
        html('<figure id="' .. img.identifier .. '">'),
        pandoc.Plain({ pandoc.Image(pandoc.Inlines({}), img.src, '') }),
        html('<figcaption><span class="label">Figure ' .. n .. '.</span>'),
        pandoc.Plain(img.caption),
        html('</figcaption></figure>'),
      }
      return out
    end
  end
  return nil
end

local function Header(el)
  if el.identifier == '' then return nil end
  local n = num[el.identifier]
  local tag = 'h' .. el.level
  local prefix = n and ('<span class="secno">' .. n .. '</span> ') or ''
  local text = pandoc.utils.stringify(el.content)
  return html(
    '<' .. tag .. ' id="' .. el.identifier .. '">' .. prefix ..
    text:gsub('&', '&amp;'):gsub('<', '&lt;') .. '</' .. tag .. '>'
  )
end

-- ---------------------------------------------------------------- driver

function Pandoc(doc)
  local raw = doc.meta.bibkeys and pandoc.utils.stringify(doc.meta.bibkeys) or ''
  for k in raw:gmatch('[^,]+') do
    bibkeys[#bibkeys + 1] = k
    bibnum[k] = #bibkeys
  end

  -- Anything before the first \section is title-block residue (\markboth's
  -- running head, stray \thanks text); the page renders its own header.
  local body = pandoc.Blocks({})
  local started = false
  for _, b in ipairs(doc.blocks) do
    if not started and b.t == 'Header' then started = true end
    if started then body:insert(b) end
  end
  doc.blocks = started and body or doc.blocks

  collect(doc.blocks)

  local blocks = doc.blocks:walk({
    Link = Link, Cite = Cite, Math = Math, Image = Image,
    CodeBlock = CodeBlock,
  })
  blocks = blocks:walk({ Div = Div, Figure = Figure, Para = Para, Header = Header })

  return pandoc.Pandoc(blocks, doc.meta)
end
