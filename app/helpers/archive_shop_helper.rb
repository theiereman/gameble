module ArchiveShopHelper
  def archive_offer_key(card) = "#{card.id}-#{card.season_number}"

  def archive_offer_dom_id(card) = "archive-offer-#{archive_offer_key(card)}"

  def archive_offer_selector(card) = "[data-archive-offer='#{archive_offer_key(card)}']"

  def archive_offer_path(card, buyable:)
    buyable ? new_market_archive_purchase_path(slug: card.id, number: card.season_number) : card_season_path(slug: card.id, number: card.season_number)
  end

  def archive_offer_label(row, wanted:, buyable:, stock:, caps: {})
    card = row.card
    parts = [ t("market.shops.offer.label", card: card.title, rarity: CardStrings.new.rarity_name(card.rarity), season: card.season_number,
      price: picoins_label(row.price)) ]
    parts << t("market.shops.offer.stock", count: row.stock) if stock
    parts << t("market.shops.offer.wanted_spoken") if wanted
    cap = archive_cap_line(card, caps)
    parts << cap if cap
    label = parts.join(", ")
    buyable ? "#{label}. #{t("market.shops.offer.buy_spoken")}" : label
  end

  def archive_cap_line(card, caps) = archive_rarity_cap_line(card.rarity, caps)

  def archive_rarity_cap_line(rarity, caps)
    standing = caps[rarity.to_sym]
    return unless standing

    window = archive_cap_window(standing.window_days)
    return t("market.archive_cap.left", cap: standing.left, rarity: archive_cap_rarity(rarity, standing.left), window:) unless standing.reached?

    t("market.archive_cap.reached", cap: standing.cap, rarity: archive_cap_rarity(rarity, standing.cap), window:, date: archive_cap_date(standing))
  end

  def archive_cap_date(standing) = l((standing&.next_at || Time.current).to_date, format: :day_month)

  def market_shop_filtered_path(filters, **extra) = market_shop_path(**filters.to_params, **extra.compact)

  private
    def archive_cap_rarity(rarity, count) = t("market.archive_cap.rarity.#{rarity}", count:)

    def archive_cap_window(days)
      case days
      when 1 then t("market.archive_cap.window.day")
      when 7 then t("market.archive_cap.window.week")
      else t("market.archive_cap.window.days", count: days)
      end
    end
end
