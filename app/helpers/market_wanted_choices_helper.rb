module MarketWantedChoicesHelper
  WANTED_CHILDREN = %w[wanted-dock].freeze
  WANTED_ACTIONS = "submit->wanted-table#submit turbo:submit-end->wanted-table#released keydown.enter->wanted-table#holdEnter".freeze

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
end
