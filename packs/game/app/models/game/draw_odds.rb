module Game
  # The odds of a draw, per card, in parts per ten thousand, keyed by rarity
  # tier (Catalog::Rarity::TIERS, 1 common … 5 legendary). Each table sums to
  # TOTAL (catalog-and-rarity.md, Draw).
  module DrawOdds
    TOTAL = 10_000

    # A regular pack: common 76 %, uncommon 19 %, rare 4.3 %,
    # epic 0.65 %, legendary 0.05 %.
    REGULAR = { 1 => 7_600, 2 => 1_900, 3 => 430, 4 => 65, 5 => 5 }.freeze

    # The card forced by the first-session guarantee: rare or better, in
    # the regular odds' proportions (430 : 65 : 5).
    GUARANTEE = { 3 => 8_600, 4 => 1_300, 5 => 100 }.freeze

    # A daily bonus pack (CAP-16): better odds and no common, uncommon 70 %,
    # rare 24 %, epic 5 %, legendary 1 %. The booster odds are an open
    # product question (spec); this is the assumption recorded in the epic
    # Notes and pending-approvals.md, held here and nowhere else.
    BONUS = { 2 => 7_000, 3 => 2_400, 4 => 500, 5 => 100 }.freeze
  end
end
