module FeedItems
  def self.call(entries, locale: I18n.locale)
    cards = Catalog::CardViews.call(entries.flat_map { [ it.entry.card_season_id, it.entry.partner_card_season_id ] }.compact, locale:)
    entries.filter_map do |item|
      card = cards[item.entry.card_season_id]
      partner_card = cards[item.entry.partner_card_season_id] if item.entry.partner_card_season_id
      next unless card
      next if item.entry.partner_card_season_id && !partner_card

      [ item, card, partner_card ]
    end
  end
end
