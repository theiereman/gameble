module SocialHelper
  TURN_TONES = { yours: "alert", theirs: "accent" }.freeze
  PIPS_SHOWN = 6
  NAMED_AT_MOST = 3

  TradeSide = Data.define(:count, :pips, :overflow, :best)

  def trade_side(lines, cards)
    rarities = lines.flat_map { |line| Array.new(line.quantity) { cards[line.card_season_id]&.rarity } }.compact
    ordered = rarities.sort_by { -rarity_tier(it) }
    TradeSide.new(count: lines.sum(&:quantity), pips: ordered.first(PIPS_SHOWN), overflow: [ ordered.size - PIPS_SHOWN, 0 ].max, best: ordered.first)
  end

  def rarity_tier(rarity) = Catalog::Rarity::TIERS.key(rarity.to_sym) || 0

  def social_trade_chip(row)
    [ TURN_TONES.fetch(row.state), t("pages.social.trades.#{row.state}") ]
  end

  def social_others_chip(rows) = social_trade_chip(rows.find { it.state == :yours } || rows.first)

  def names_and_others(names)
    shown = names.first(NAMED_AT_MOST)
    rest = names.size - shown.size
    return t("pages.social.others.more", names: shown.join(", "), count: rest) if rest.positive?
    return shown.join if shown.size < 2

    t("pages.social.others.all", names: shown[0..-2].join(", "), last: shown.last)
  end

  def trade_side_sentence(key, side, name: nil)
    rarity = side.best && t("catalog.rarity.#{side.best}")
    t("pages.social.trades.#{key}", count: side.count, name:, rarity:)
  end
end
