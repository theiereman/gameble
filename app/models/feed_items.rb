module FeedItems
  def self.call(entries, locale: I18n.locale)
    cards = Catalog::CardViews.call(entries.map { it.entry.card_season_id }, locale:)
    entries.filter_map { |item| [ item, cards[item.entry.card_season_id] ] if cards[item.entry.card_season_id] }
  end
end
