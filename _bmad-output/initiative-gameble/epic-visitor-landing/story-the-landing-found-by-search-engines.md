---
id: 18
tracker_status: done
tracker_id: 183
remote: https://github.com/theiereman/gameble/issues/183
type: story
title: "The landing found by search engines"
parent: epic-visitor-landing
covers: [R1]
after: [7.3, 15]
hitl: false
risk: low
---

# The landing found by search engines

## Description

Makes the landing the page search engines find and present well: its title and meta description in both languages, hreflang between /fr and /en, canonical links on PUBLIC_URL, structured data for the game, a sitemap listing the landing and the legal page, and a robots.txt that points to it and disallows the back-office and private screens. Public card pages, public profiles and the library keep their sharing previews and stay indexable, with no further search work.

## Acceptance Criteria

Verify: The landing has its own title and description in each language with hreflang and canonical links and valid structured data; /sitemap.xml lists the landing and the legal page in both languages and no private page; robots.txt points to the sitemap and disallows the back-office and private screens; public card pages and profiles are not marked noindex.

## References

- parent — _bmad-output/initiative-gameble/epic-visitor-landing/epic-visitor-landing.md

## Notes

- il faudra ajouter des tickets pour favoriser le SEO
- Decision (author, 2026-10-14): search work aims at the landing; public card pages, public profiles and the library stay indexable but get no search work, and are not marked noindex.
