module SocialHelper
  TURN_TONES = { yours: "alert", theirs: "accent" }.freeze
  PIPS_SHOWN = 6

  TradeSide = Data.define(:count, :pips, :overflow, :best)

  def trade_side(lines, cards)
    rarities = lines.flat_map { |line| Array.new(line.quantity) { cards[line.card_season_id]&.rarity } }.compact
    ordered = rarities.sort_by { -rarity_tier(it) }
    TradeSide.new(count: lines.sum(&:quantity), pips: ordered.first(PIPS_SHOWN), overflow: [ ordered.size - PIPS_SHOWN, 0 ].max, best: ordered.first)
  end

  def rarity_tier(rarity) = Catalog::Rarity::TIERS.key(rarity.to_sym) || 0

  def social_trade_chip(row)
    return [ "muted", t("trades.chip.#{row.state}") ] unless row.open?

    [ TURN_TONES.fetch(row.state), t("pages.social.trades.#{row.state}") ]
  end

  def trade_side_sentence(key, side, name: nil)
    rarity = side.best && t("catalog.rarity.#{side.best}")
    t("pages.social.trades.#{key}", count: side.count, name:, rarity:)
  end
end
