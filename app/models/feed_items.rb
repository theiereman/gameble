module FeedItems
  Move = Data.define(:card, :stat, :from, :to) do
    def rose? = to > from
  end

  def self.call(entries, locale: I18n.locale)
    cards = Catalog::CardViews.call(entries.flat_map { card_season_ids(it.entry) }, locale:)
    sets = Catalog::SetsById.call(entries.filter_map { it.entry.set_id })
    entries.filter_map do |item|
      next [ item, nil, nil, nil ] if item.entry.kind == "verdict"
      next duel_stats_item(item, cards) if item.entry.kind == "duel_stats"
      next if item.entry.kind == "sale" && item.price.nil?

      if item.entry.set_id
        set = sets[item.entry.set_id]
        [ item, nil, nil, set ] if set
      else
        card = cards[item.entry.card_season_id]
        partner_card = cards[item.entry.partner_card_season_id] if item.entry.partner_card_season_id
        next unless card
        next if item.entry.partner_card_season_id && !partner_card

        [ item, card, partner_card, nil ]
      end
    end
  end

  def self.card_season_ids(entry)
    [ entry.card_season_id, entry.partner_card_season_id, *entry.moves&.map { it.fetch("card_season_id") } ].compact
  end
  private_class_method :card_season_ids

  def self.duel_stats_item(item, cards)
    moves = item.entry.moves.filter_map do |move|
      card = cards[move.fetch("card_season_id")]
      Move.new(card:, stat: move.fetch("stat"), from: move.fetch("from"), to: move.fetch("to")) if card
    end
    [ item, nil, nil, nil, moves ] if moves.any?
  end
  private_class_method :duel_stats_item
end
