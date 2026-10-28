---
id: 13
tracker_status: done
tracker_id: ""
type: bug
title: "The all cards page title names the collection"
parent: epic-screen-walkthrough
after: []
refined: false
hitl: false
risk: low
---

# The all cards page title names the collection

## Description

The browser title of the catalog (`library/cards`, `config/locales/fr.yml` line 826 and its `en.yml` twin) reads "Toutes les cartes · Collection · gameble" / "All cards · Collection · gameble", which a visitor without a collection reads as another screen (author, 2026-10-23, on staging). Make it "Toutes les cartes · gameble" and "All cards · gameble".

## Acceptance Criteria

Verify: The title of `/fr/library/cards` and `/en/library/cards` reads "Toutes les cartes · gameble" and "All cards · gameble", signed out and signed in; the page's request test and `i18n-tasks` pass.

## References

- parent — _bmad-output/initiative-gameble/epic-screen-walkthrough/epic-screen-walkthrough.md

## Notes

- Found in the screen walkthrough (ticket 16.1, finding 4), author, 2026-10-23.
