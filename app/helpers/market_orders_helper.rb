module MarketOrdersHelper
  # The form's rarity reach, for display only: the order's own reach is Order.reaching's.
  def order_reached(minimums, price) = price ? minimums.select { |_, minimum| minimum <= price }.keys : []

  def order_reach_sentence(minimums, price)
    reached = order_reached(minimums, price)
    return t("market.orders.strings.all") if reached.size == minimums.size

    rarity, amount = minimums.except(*reached).min_by(&:last)
    upcoming = { next: t("market.orders.strings.next.#{rarity}"), amount: picoins(amount) }
    return t("market.orders.strings.none", **upcoming) if reached.empty?

    t("market.orders.strings.some", reached: order_rarity_words(reached), **upcoming)
  end

  def order_rarity_words(rarities)
    rarities.map { t("market.orders.strings.reached.#{it}") }
      .to_sentence(two_words_connector: t("market.orders.list.two_words"), last_word_connector: t("market.orders.list.last_word"))
  end

  def order_form_data(minimums)
    { controller: "order-form", action: "submit->order-form#submit turbo:submit-end->order-form#submitted",
      order_form_minimums_value: minimums.to_json, order_form_strings_value: screen_strings("market.orders.strings").to_json,
      order_form_locale_value: I18n.locale }
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

  ORDER_TONES = { "open" => :accent, "served" => :lime, "expired" => :muted, "cancelled" => :muted }.freeze

  def order_row_facts(row)
    [ [ t("market.orders.labels.held"), row_amount(row.price) ], [ t("market.orders.labels.end"), row_end(row.expires_at, row.ended_at) ] ]
  end

  def order_status_label(status) = status == "open" ? t("market.rows.status.in_progress") : t("market.my_orders.status.#{status}")

  def order_status_tone(status) = ORDER_TONES.fetch(status)

  def order_row_note(row)
    case row.status
    when "served"
      return unless row.served

      t("market.my_orders.served_html", name: render(PlayerNameComponent.new(player: row.seller, viewer: current_player)),
        rarity: CardStrings.new.rarity_name(row.served.rarity), season: row.served.season_number)
    when "expired", "cancelled" then t("market.my_orders.returned")
    end
  end

  def order_cancel_dialog_id(token) = "cancel-order-#{token}"
end
