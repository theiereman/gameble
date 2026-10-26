---
id: 1
tracker_status: in-progress
tracker_id: 227
remote: https://github.com/theiereman/gameble/issues/227
type: story
title: "The trade board in Stimulus"
parent: epic-port-off-react
covers: [R1, R4, R5, R6]
after: [16.1]
hitl: false
risk: medium
---

# The trade board in Stimulus

## Description

Ports the trade board to a `trade-board` root controller and its child controllers over a module in `app/frontend/lib`, folds the existing `trade-board`, `trade-send` and `trade-swap` controllers into that anatomy, renders its copy per AD-18 under `trade_board.strings`, adds the shared helper that places server HTML from a JSON answer into a `<template>` (used here by the faces batch, then by the booster), tested in Vitest under happy-dom set for that test file alone (a devDependency and a Stack row), with the CI step, in `config/ci.rb` and `.github/workflows/ci.yml`, that fails on markup-building APIs outside it, moves the draft's storage behind a module, and removes `TradeBoard`, `TradePicker`, `QuantityStepper` and the `trade-changed` and `trade-editing` events; its module, controllers, outlets and strings scope set the conventions the booster follows.

## Acceptance Criteria

Verify: `test/system/trades_test.rb` passes unchanged but for renamed locale scopes, Vitest covers every transition of the trade board's module and the helper, and the CI step fails on a planted `innerHTML`.

## References

- parent — _bmad-output/initiative-gameble/epic-port-off-react/epic-port-off-react.md

## Notes

- Unknown: Whether the board and its picker fit one session; if not, it is split on a branch merged once, never React and Stimulus side by side on develop.
