module MarketOrdersHelper
  def order_rarity_words(rarities)
    rarities.map { t("market.orders.strings.reached.#{it}") }
      .to_sentence(two_words_connector: t("market.orders.list.two_words"), last_word_connector: t("market.orders.list.last_word"))
  end

  def order_form_data
    { controller: "order-form", action: "submit->order-form#submit turbo:submit-end->order-form#submitted", order_form_locale_value: I18n.locale }
  end

  def order_days(days) = t("market.orders.days", count: days, number: number_with_delimiter(days))

  def order_rarity_pills(rarities)
    names = CardStrings.new
    tag.span(class: "order-pills") do
      safe_join(rarities.map do |rarity|
        tag.span(class: "order-pill order-pill--#{rarity}") do
          tag.span(t("market.orders.letters.#{rarity}"), aria: { hidden: true }) + tag.span(names.rarity_name(rarity), class: "visually-hidden")
        end
      end)
    end
  end

  ORDER_TONES = { "open" => :accent, "bid" => :accent, "served" => :lime, "won" => :lime, "expired" => :muted, "cancelled" => :muted, "outbid" => :muted }.freeze

  def order_row_facts(row)
    [ [ t("market.orders.labels.held"), row_amount(row.price) ], [ t("market.orders.labels.end"), row_end(row.expires_at, row.ended_at) ] ]
  end

  def order_status_label(status) = status == "open" ? t("market.rows.status.in_progress") : t("market.my_orders.status.#{status}")

  def order_status_tone(status) = ORDER_TONES.fetch(status)

  def order_row_note(row)
    case row.status
    when "open" then order_listed_above_note(row) if row.listed_above
    when "served"
      return unless row.served

      t("market.my_orders.served_html", name: render(PlayerNameComponent.new(player: row.seller, viewer: current_player)),
        rarity: CardStrings.new.rarity_name(row.served.rarity), season: row.served.season_number)
    when "expired", "cancelled" then t("market.my_orders.returned")
    when "bid" then order_listing_link(row)
    when "won" then safe_join([ t("market.my_orders.joins_collection"), order_listing_link(row) ], " ")
    when "outbid" then safe_join([ t("market.my_orders.returned"), order_listing_link(row) ], " ")
    end
  end

  def order_listing_link(row)
    render(ButtonComponent.new(variant: :link, href: market_listing_path(token: row.listing_token)).with_content(t("market.my_orders.see_listing"))) if row.listing_token
  end

  def order_listed_above_note(row)
    above = row.listed_above
    line = t("market.my_orders.listed_above_html", name: render(PlayerNameComponent.new(player: above.seller, viewer: current_player)),
      card: row.card.title, amount: render(PicoinAmountComponent.new(amount: above.amount)))
    link = render(ButtonComponent.new(variant: :link, href: market_listing_path(token: above.token)).with_content(t("market.my_orders.see_listing")))
    safe_join([ line, link ], " ")
  end

  def order_cancel_dialog_id(token) = "cancel-order-#{token}"

  def order_back(from, card)
    case from
    when "my_orders" then [ t("shell.screens.my_orders"), market_my_orders_path ]
    when "card" then [ t("shell.screens.card"), card_path(slug: card.id) ]
    else [ t("market.listings.show.back"), market_path ]
    end
  end

  def order_back_data(from) = from == "card" ? { controller: "history-back", action: "history-back#back" } : {}

  def order_listing_name(row)
    t("market.orders.new.listing_name", rarity: CardStrings.new.rarity_name(row.card.rarity), season: row.card.season_number, name: (row.seller ? duel_plain_name(row.seller) : t("player_name.archives")),
      amount: picoins(row.current_price))
  end
end
