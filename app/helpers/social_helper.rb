module SocialHelper
  TURN_TONES = { yours: "alert", theirs: "accent" }.freeze

  def trade_top_rarity(row, cards)
    row.card_season_ids.filter_map { cards[it]&.rarity }.max_by { rarity_tier(it) }
  end

  def rarity_tier(rarity) = Catalog::Rarity::TIERS.key(rarity.to_sym) || 0

  def social_trade_chip(row)
    return [ "muted", t("trades.chip.#{row.state}") ] unless row.open?

    [ TURN_TONES.fetch(row.state), t("pages.social.trades.#{row.state}") ]
  end
end
