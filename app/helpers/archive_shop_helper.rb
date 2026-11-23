module ArchiveShopHelper
  def archive_offer_key(card) = "#{card.id}-#{card.season_number}"

  def archive_offer_dom_id(card) = "archive-offer-#{archive_offer_key(card)}"

  def archive_offer_selector(card) = "[data-archive-offer='#{archive_offer_key(card)}']"

  def archive_offer_path(card, buyable:)
    buyable ? new_market_archive_purchase_path(slug: card.id, number: card.season_number) : card_season_path(slug: card.id, number: card.season_number)
  end

  def archive_offer_label(row, wanted:, buyable:, stock:)
    card = row.card
    parts = [ t("market.shops.offer.label", card: card.title, rarity: CardStrings.new.rarity_name(card.rarity), season: card.season_number,
      price: picoins_label(row.price)) ]
    parts << t("market.shops.offer.stock", count: row.stock) if stock
    parts << t("market.shops.offer.wanted_spoken") if wanted
    label = parts.join(", ")
    buyable ? "#{label}. #{t("market.shops.offer.buy_spoken")}" : label
  end

  def market_shop_filtered_path(filters, **extra) = market_shop_path(**filters.to_params, **extra.compact)
end
