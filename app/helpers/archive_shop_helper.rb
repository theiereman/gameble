module ArchiveShopHelper
  def archive_offer_key(card) = "#{card.id}-#{card.season_number}"

  def archive_offer_dom_id(card) = "archive-offer-#{archive_offer_key(card)}"

  def archive_offer_selector(card) = "[data-archive-offer='#{archive_offer_key(card)}']"

  def archive_offer_path(card, buyable:)
    buyable ? new_market_archive_purchase_path(slug: card.id, number: card.season_number) : card_season_path(slug: card.id, number: card.season_number)
  end

  def archive_offer_label(row, wanted:, stock:, ownership: nil)
    card = row.card
    parts = [ t("market.shops.offer.label", card: card.title, rarity: CardStrings.new.rarity_name(card.rarity), season: card.season_number,
      price: picoins_label(row.price)) ]
    parts << t("market.shops.offer.stock", count: row.stock) if stock
    parts << t("market.shops.offer.wanted_spoken") if wanted
    parts << ownership if ownership
    parts.join(", ")
  end

  def archive_cap_line(card, caps) = archive_rarity_cap_line(card.rarity, caps)

  def archive_rarity_cap_line(rarity, caps)
    standing = caps[rarity.to_sym]
    return unless standing&.reached?

    local_time_sentence(standing.next_at) { t("market.archive_cap.reached", cap: standing.cap, date: it) }
  end

  def archive_auction_terms
    { epics: Game::Market::ArchiveAuctionPicks::RARITIES[:epic], legendaries: Game::Market::ArchiveAuctionPicks::RARITIES[:legendary],
      hours: Game::Market::OpenArchiveAuction::DURATION_HOURS }
  end

  def archive_cap_date(standing) = local_time_text(standing&.next_at || Time.current)

  def market_shop_filtered_path(filters, **extra) = market_shop_path(**filters.to_params, **extra.compact)
end
