import { withBase } from './url';

/**
 * Everything the head tags, the JSON-LD and the Google Scholar citation tags
 * need, in one place. Kept here rather than inline in the layout so the paper
 * metadata -- DOI, ORCID, publication date -- has a single source of truth.
 */
export const SITE = {
  name: 'vphilox',
  tagline: 'Portable, seekable random streams for parallel CPU simulation',
  /** Must match `site` in astro.config.mjs. */
  origin: 'https://sinhaparth5.github.io',
  locale: 'en_GB',
  description:
    'vphilox is a header-only C++20 library built on Philox4x32-10: a counter-based ' +
    'generator whose entire state is a key and a position, so a stream is reproducible ' +
    'across standard libraries, instruction sets and thread counts.',
  repo: 'https://github.com/sinhaparth5/vphilox',
  ogImage: 'og.png',
} as const;

export const AUTHOR = {
  name: 'Parth Sinha',
  orcid: 'https://orcid.org/0009-0002-3120-9301',
  affiliation: 'Independent Researcher, Oxford, United Kingdom',
} as const;

export const PAPER = {
  title: 'Portable, Seekable Random Streams for Parallel CPU Simulation',
  doi: '10.5281/zenodo.22103483',
  doiUrl: 'https://doi.org/10.5281/zenodo.22103483',
  /** `date-released` in the upstream CITATION.cff. */
  published: '2026-08-26',
  pdf: 'vphilox.pdf',
  license: 'https://opensource.org/licenses/MIT',
} as const;

/**
 * A fully-qualified URL for an internal path, base included. Canonical links,
 * `og:*` and JSON-LD all need absolute URLs -- a root-relative one is ignored
 * by most consumers.
 */
export function absolute(path = ''): string {
  return new URL(withBase(path), SITE.origin).href;
}

/**
 * The canonical form of the page currently being rendered.
 *
 * GitHub Pages redirects an extensionless directory path to its trailing-slash
 * form, so the canonical has to carry the slash -- otherwise every canonical on
 * the site points at a 301.
 */
export function canonical(pathname: string): string {
  const last = pathname.split('/').pop() ?? '';
  const path = last.includes('.') || pathname.endsWith('/') ? pathname : `${pathname}/`;
  return new URL(path, SITE.origin).href;
}
