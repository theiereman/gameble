module MarketHelper
  SOON_SECONDS = 3600

  def listing_seconds_left(ends_at) = [ (ends_at - Time.current).floor, 0 ].max

  def listing_time_left(seconds)
    if seconds >= SOON_SECONDS
      t("markets.time_left.hours", hours: seconds / SOON_SECONDS, minutes: format("%02d", seconds % SOON_SECONDS / 60))
    elsif seconds >= 60
      t("markets.time_left.minutes", minutes: seconds / 60)
    else
      t("markets.time_left.under")
    end
  end

  def time_left_soon?(seconds) = seconds < SOON_SECONDS

  def listing_tile_label(row)
    card = row.card
    label = t("markets.tile.label", card: card.title, rarity: CardStrings.new.rarity_name(card.rarity), season: card.season_number,
      price: t("picoin_amount.accessible", amount: picoins(row.current_price)), offers: t("markets.tile.offers", count: row.offers),
      time: local_time_text(row.ends_at, :time))
    return label unless row.buy_now_price

    "#{label}, #{t("markets.tile.label_buy_now", price: t("picoin_amount.accessible", amount: picoins(row.buy_now_price)))}"
  end

  def sort_options = Game::Market::OpenListings::ORDERS.keys

  def market_filtered_path(filters, **extra) = market_path(**filters.to_params, **extra.compact)

  def clock_data(seconds)
    { controller: "listing-clock", listing_clock_seconds_value: seconds,
      listing_clock_hours_template_value: t("markets.time_left.hours", hours: "%{hours}", minutes: "%{minutes}"),
      listing_clock_minutes_template_value: t("markets.time_left.minutes", minutes: "%{minutes}"),
      listing_clock_under_template_value: t("markets.time_left.under") }
  end
end
