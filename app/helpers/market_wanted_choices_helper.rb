module MarketWantedChoicesHelper
  WANTED_CHILDREN = %w[wanted-dock].freeze
  WANTED_ACTIONS = "submit->wanted-table#submit turbo:submit-end->wanted-table#released keydown.enter->wanted-table#holdEnter".freeze

  ResultRow = Data.define(:kind, :copies, :amount, :commission, :listing, :stamp, :led_price)

  def wanted_root_data(focus:)
    { controller: "wanted-table", action: WANTED_ACTIONS, wanted_table_locale_value: I18n.locale, wanted_table_cap_left_value: @cap_left, wanted_table_available_value: @available,
      wanted_table_basis_points_value: @settings.commission_basis_points, wanted_table_focus_value: focus,
      wanted_table_strings_value: screen_strings("market.wanted_choices.strings").merge("overCap" => t("market.entrustments.strings.over_cap")) }
      .compact.merge(screen_outlets("wanted-table", WANTED_CHILDREN))
  end

  def wanted_line_data(line, title:, changed:)
    { wanted_table_target: "line", ref: line.ref, title:, copies: line.copies, value: line.value, minimum: line.minimum, stamp: line.stamp,
      average: line.price.average.to_s, orders: (line.direct? ? line.orders.map(&:price) : line.backing).join(","), direct: line.direct?.to_s, changed: changed.to_s }
  end

  def wanted_choice_options(line, choice:, note_id:)
    order = line.orders.first
    entrusted = line.value * line.copies
    action = { action: "change->wanted-table#choose" }
    [ ({ value: "order", label: t("market.wanted_choices.new.choices.order"), amount: order&.price, checked: choice == "order", disabled: order.nil?,
         accessible: (t("market.wanted_choices.new.order_label", amount: picoins(order.price)) if order), data: action } if line.direct?),
      { value: "auction", label: t("market.wanted_choices.new.choices.auction"), checked: choice == "auction", describedby: note_id, data: action },
      { value: "entrust", label: t("market.wanted_choices.new.choices.entrust"), amount: entrusted, checked: choice == "entrust",
        accessible: t("market.wanted_choices.new.entrust_label", amount: picoins(entrusted)), data: action } ].compact
  end

  def wanted_group_description(line, id:, changed:)
    [ ("wanted-dock-refusal #{id}-changed" if changed), (("#{id}-no-order" unless line.orders.any?) if line.direct?), ("#{id}-backed-note" unless line.direct?) ]
      .compact.join(" ").presence
  end

  def wanted_result_heading(choices, applied)
    return t("market.wanted_choices.result.heading", count: choices) if applied == choices

    t("market.wanted_choices.result.partial", applied:, count: choices)
  end

  # What one table line became: a row for its sales, one for its auctions and one for its entrusted copies, each said once with its count.
  def wanted_result_rows(applied, index, stamp:)
    sold = applied.sold.select { it.line == index }
    listed = applied.listed.select { it.line == index }
    entrusted = applied.entrusted.select { it.line == index }
    [ (ResultRow.new(:sold, sold.size, sold.sum(&:received), sold.sum { it.order.price - it.received }, nil, 0, nil) if sold.any?),
      (ResultRow.new(:listed, listed.size, listed.sum { listed_received(it.listing) }, 0, listed.first.listing, stamp * listed.size,
        listed.map(&:listing).find(&:leader_id)&.current_price) if listed.any?),
      (ResultRow.new(:entrusted, entrusted.sum(&:copies), entrusted.sum(&:minted), 0, nil, 0, nil) if entrusted.any?) ].compact
  end

  private
    def listed_received(listing) = listing.starting_price - Game::Market::AuctionMath.commission(listing.starting_price, @settings.commission_basis_points)
end
