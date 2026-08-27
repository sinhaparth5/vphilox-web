# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

`CLAUDE.md` is a symlink to `AGENTS.md` — edit `AGENTS.md` so both stay in sync.

## Commands

| Command | Action |
| :-- | :-- |
| `npm run dev` | Dev server on `localhost:4321` |
| `npm run build` | Production build to `./dist/` (also runs the type check) |
| `npm run preview` | Serve the built `dist/` locally |
| `npm run astro -- <cmd>` | Astro CLI (`add`, `check`, `sync`, …) |

When starting the dev server, use background mode:

```
astro dev --background
```

Manage the background server with `astro dev stop`, `astro dev status`, and `astro dev logs`.

There is no test runner, linter, or formatter configured. `astro check` is not usable
until `@astrojs/check` + `typescript` are installed (`npx astro add check`); until then,
`npm run build` is the only type/template validation.

Node >= 22.12.0 is required (`engines` in package.json). Astro 7 with the Rolldown-based Vite.

## Architecture

A static site publishing the vPhilox paper and hand-written explainers, deployed to
GitHub Pages at `https://sinhaparth5.github.io/vphilox-web`.

- `base: '/vphilox-web'` is set in `astro.config.mjs`. **Never write a bare `/foo` href** —
  import `withBase` from `@lib/url` and wrap every internal link and asset path.
  (The helper is named `withBase`, not `url`: `url` collides with an identifier Astro
  injects into MDX scope.)
- **Math**: `remark-math` + `rehype-katex`, rendered at build time (no runtime JS).
  Astro 7 defaults to the `satteri` markdown processor, which does not take remark/rehype
  plugins, so `markdown.processor` is set to `unified()` from `@astrojs/markdown-remark`.
  `katex/dist/katex.min.css` is imported by `src/layouts/Base.astro`.
- **Fonts**: Astro 7's built-in `fonts` config self-hosts from Google at build time and
  exposes `--font-body` (Source Serif 4), `--font-head` (Source Sans 3), `--font-mono`
  (Source Code Pro). Faces are emitted by `<Font>` from `astro:assets` in the layout.
  Do not add `@fontsource/*` packages or `<link>` tags to Google.
- **Styling** is hand-written CSS in modules under `src/styles/` — no Tailwind. The
  layout imports only `index.css`, which `@import`s the rest in cascade order:
  `tokens` → `reset` → `layout` → `chrome` → `typography` → `figures` → `math` →
  `anim` → `motion` → `print`. Vite inlines the imports at build time, so add a new
  module by creating the file and listing it in `index.css`. Component-specific rules
  belong in that component's scoped `<style>`, not here.
  Do **not** nest `@media` inside a selector block; Astro does not downlevel native
  CSS nesting.
- **The site is light only.** There is no theme toggle and no `prefers-color-scheme`
  palette. All the line art — the generated plots, KaTeX, the diagrams — is dark on
  paper, and a second palette was a second thing to keep in sync for no gain. Do not
  reintroduce one without also handling the plot SVGs, which would need inverting.
- **Nothing sits in a card.** Figures, code blocks and the nav cards have no border
  and no surface of their own; they are ink on the same paper as the text. Depth
  comes from fills a step either side of `--bg`: `--bg-raised` for a shape that holds
  something, `--bg-sunk` for substrate that other shapes sit on. Line art strokes use
  `--rule-mid`, which is a step firmer than `--rule` and holds its shape on paper —
  `--rule` alone was tuned against a white card and goes faint once the card is gone.
- **Layout** is a named-line grid on `main`: content sits in the `text` column
  (`--measure`, 42rem), and `figure`/`.wide` break out to the `wide` column.

## The paper is generated, not written

`src/content/paper/vphilox.mdx` is **generated output**. Edits to it are lost. Run:

```
./scripts/convert-paper.sh          # ../vphilox/paper/vphilox.tex -> src/content/paper/vphilox.mdx
```

The `.tex` lives in the sibling `vphilox` repo, not here, so conversion is a **local
step only** — CI has no source to convert and builds the committed MDX as it stands.
Regenerate and commit the MDX yourself after a `.tex` change. Pass a path as the first
argument if the source is somewhere other than `../vphilox/paper/vphilox.tex`.

The pipeline is three parts, and a fix belongs in whichever one owns the problem:

1. `scripts/pre-pass.sed` — rewrites `table*`/`figure*` to their single-column forms
   (pandoc silently drops `\caption` and `\label` inside the starred versions) and
   expands `\IEEEPARstart`.
2. `scripts/tex-to-mdx.lua` — numbers sections/figures/tables/equations, rewrites
   `\cref` into "Section 3.2", turns `\cite` into links into the reference list, and
   rebuilds `thebibliography` (pandoc discards `\bibitem` keys, so the driver passes
   the key order in via `-M bibkeys=`).
3. `src/content/paper/_algorithm.mdx.part` — the `algorithm2e` body, which pandoc drops
   entirely. The filter splices this file in.

### MDX constraints the filter has to respect

These all caused build failures once; the filter encodes the fixes.

- HTML comments (`<!-- -->`) are invalid; use `{/* */}`.
- Autolinks (`<https://…>`) parse as JSX; emit `[url](url)`.
- Indented code blocks are unsupported; every `CodeBlock` gets a language class so
  pandoc fences it.
- Markdown children inside a JSX element require the **tags to sit alone on their own
  lines**. This is why figure captions are built as one inline paragraph and why the
  equation wrapper is emitted across several lines.
- The gfm writer emits ``$`x`$`` for inline math and a bare fence for display math;
  `remark-math` parses neither, so the `Math` handler emits raw `$…$` / `$$…$$`.

## Figures

Plot SVGs are generated in the sibling `../vphilox` repo (`docs/benchmarks/plots/`) and
copied into `src/content/paper/` so Astro's asset pipeline resolves them; the filter
rewrites `.pdf` sources to `./name.svg`.

Animated explanatory SVGs are Astro components in `src/components/`, used from
`src/content/docs/*.mdx`. They share two things and differ only in the drawing:

- `src/styles/anim.css` — the figure chrome (transport controls, step tabs, progress
  rule, pan box) and the stage/wire animation vocabulary. The chrome is borderless and
  transparent, so the drawing reads as part of the page; see the fill roles above.
  A stage marked `persist`
  stays at full opacity once reached, for the substrate that later stages annotate;
  an unmarked stage recedes to 0.42 once it is no longer current.
- `src/lib/stepper.ts` — the driver. `mountStepper(selector, steps, opts)` wires the
  tabs, autoplay, arrow keys and the caption, measures every `.wire.trace` with
  `getTotalLength()` so the dash animation matches the real path length, and starts
  the figure once it scrolls into view. `opts.onRender` covers state a stage class
  cannot carry, such as which of two mutually exclusive placements is on screen.

Two constraints the drawings have to respect:

- **Never set `font-size` in CSS for SVG text.** A CSS declaration outranks an SVG
  presentation attribute, so a rule like `.cap { font-size: 12.5px }` silently
  overrides every `font-size="14"` in the markup. Sizes live in the markup; the same
  applies to `text-anchor`, which is why anchored labels get their own class rather
  than reusing `.cap`.
- **Nothing below 13px in the drawing.** The figure renders at roughly 0.85 scale in
  the `wide` column, and below 13px the labels land under 11px on the page.

`CoreTopology.astro` is generated. `scripts/gen-core-topology.py` lays the geometry
out from constants, verifies it (no two parallel wires closer than 16px, no label
within 8px of a wire it does not belong to, no label overlapping another), and writes
`src/components/_core-topology.svg.part`, which replaces everything between `</desc>`
and `</svg>` in the component. Run it once per placement arm, since only one arm is on
screen at a time and the checker sees only what it is given.

## Deploying

`.github/workflows/deploy.yml` builds on push to `master` and deploys to Pages:
`npm ci`, `npm run build`, upload. Nothing else. It used to re-run the paper conversion
and fail on a stale MDX, but the `.tex` is not in this repo, so the check could only
ever fail on a clean checkout.

`public/vphilox.pdf` is the download behind the PDF links in the header and on
`/paper`. It is committed here and updated by hand.

## Documentation

Full documentation: https://docs.astro.build

Consult these guides before working on related tasks:

- [Adding pages, dynamic routes, or middleware](https://docs.astro.build/en/guides/routing/)
- [Working with Astro components](https://docs.astro.build/en/basics/astro-components/)
- [Using React, Vue, Svelte, or other framework components](https://docs.astro.build/en/guides/framework-components/)
- [Adding or managing content](https://docs.astro.build/en/guides/content-collections/)
- [Adding styles or using Tailwind](https://docs.astro.build/en/guides/styling/)
- [Supporting multiple languages](https://docs.astro.build/en/guides/internationalization/)
