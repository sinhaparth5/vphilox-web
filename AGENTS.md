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

A single static site that publishes the vPhilox paper (`docs/vphilox.tex`, IEEEtran) and
supporting docs, with hand-authored animated SVGs explaining the experiments. Deploys to
GitHub Pages at `https://sinhaparth5.github.io/vphilox-web`.

- `base: '/vphilox-web'` is set in `astro.config.mjs`. **Every internal link and asset path
  must be base-aware** — use `import.meta.env.BASE_URL`, never a bare `/foo` href.
- **Math**: `remark-math` + `rehype-katex`, rendered to HTML at build time (no runtime JS).
  Because the math plugins are remark/rehype plugins, `markdown.processor` is set to
  `unified()` from `@astrojs/markdown-remark` rather than Astro 7's default `satteri`.
  `katex/dist/katex.min.css` must be imported by the layout or math renders unstyled.
- **Fonts**: Astro 7's built-in `fonts` config self-hosts from Google at build time and
  exposes `--font-body` (Source Serif 4), `--font-head` (Source Sans 3), and `--font-mono`
  (Source Code Pro). Emit the faces with `<Font cssVariable="..." preload />` from
  `astro/components`. Do not add `@fontsource/*` packages or `<link>` tags to Google.
- **Styling** is hand-written CSS with custom properties — no Tailwind. Keep it that way.
- **Prose** lives in `.mdx` so animated-SVG components can be embedded inline.
- Plot SVGs are generated in the sibling `../vphilox` repo under
  `docs/benchmarks/plots/`; they are copied in rather than regenerated here.

## Source material

- `docs/vphilox.tex` — the paper. `pandoc` is not installed; conversion to MDX is manual.
- `docs/vPhilox theory.md` — background theory notes.

## Documentation

Full documentation: https://docs.astro.build

Consult these guides before working on related tasks:

- [Adding pages, dynamic routes, or middleware](https://docs.astro.build/en/guides/routing/)
- [Working with Astro components](https://docs.astro.build/en/basics/astro-components/)
- [Using React, Vue, Svelte, or other framework components](https://docs.astro.build/en/guides/framework-components/)
- [Adding or managing content](https://docs.astro.build/en/guides/content-collections/)
- [Adding styles or using Tailwind](https://docs.astro.build/en/guides/styling/)
- [Supporting multiple languages](https://docs.astro.build/en/guides/internationalization/)
