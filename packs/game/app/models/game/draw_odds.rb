module Game
  # The odds of a draw, per card, in parts per ten thousand, keyed by rarity
  # tier (Catalog::Rarity::TIERS, 1 steel … 5 gold). Each table sums to
  # TOTAL (catalog-and-rarity.md, Draw).
  module DrawOdds
    TOTAL = 10_000

    # A regular pack: steel 76 %, emerald 19 %, sapphire 4.3 %,
    # amethyst 0.65 %, gold 0.05 %.
    REGULAR = { 1 => 7_600, 2 => 1_900, 3 => 430, 4 => 65, 5 => 5 }.freeze
  end
end
