module MarketWantedHelper
  def wanted_tile_mark(copies) = ListingMarks::Mark.new(copies:, goals: [], wanted: false)

  def wanted_tile_label(copy, card, mark)
    values = { card: card.title, rarity: CardStrings.new.rarity_name(card.rarity), season: card.season_number,
               seekers: t("markets.wanted.seekers", count: copy.seekers), owned: listing_ownership_text(mark, spoken: true) }
    return t("markets.wanted.tile_label_no_order", **values) unless copy.order

    t("markets.wanted.tile_label", amount: picoins(copy.order.price), **values)
  end
end
