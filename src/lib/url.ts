const BASE = import.meta.env.BASE_URL.replace(/\/+$/, '');

/**
 * Build a site-absolute URL that respects `base` in astro.config.mjs.
 * The site is served from a project page (/vphilox-web), so a bare "/paper"
 * would 404 -- every internal link has to go through here.
 */
export function withBase(path = ''): string {
  return `${BASE}/${String(path).replace(/^\/+/, '')}`;
}
