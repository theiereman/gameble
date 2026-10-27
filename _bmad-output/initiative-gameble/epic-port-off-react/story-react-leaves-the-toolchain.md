---
id: 4
tracker_status: done
tracker_id: 230
remote: https://github.com/theiereman/gameble/issues/230
type: story
title: "React leaves the toolchain"
parent: epic-port-off-react
covers: [R7]
after: [3]
hitl: false
risk: low
---

# React leaves the toolchain

## Description

Removes every React and Turbo Mount package, plugin, tag, compiler option and Stack row that AD-31 lists, and tightens the development script policy if nothing else needs it.

## Acceptance Criteria

Verify: `bin/ci`, `npm run test:js` and `bin/rails zeitwerk:check` pass, and no lockfile names react, react-dom, `@types/react`, turbo-mount or `@vitejs/plugin-react`.

## References

- parent — _bmad-output/initiative-gameble/epic-port-off-react/epic-port-off-react.md
