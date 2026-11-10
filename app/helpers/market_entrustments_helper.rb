module MarketEntrustmentsHelper
  ENTRUST_ACTIONS = {
    "entrust-filters" => { change: :filter, clear: :clear },
    "entrust-grid" => { toggle: :toggle, copies: :copies, bump: :bump, move: :move, clear: :clear },
    "entrust-recap" => { copies: :copies }
  }.freeze
  ENTRUST_WINDOW_ACTIONS = "gameble:sheet-shown@window->entrust#sheetShown".freeze

  def entrust_root_data(open:, cap_left:, doubles: true)
    { controller: "entrust", action: "#{screen_actions("entrust", ENTRUST_ACTIONS)} #{ENTRUST_WINDOW_ACTIONS}",
      entrust_locale_value: I18n.locale, entrust_cap_left_value: cap_left, entrust_open_value: open, entrust_doubles_value: doubles,
      entrust_strings_value: screen_strings("market.entrustments.strings") }
      .merge(screen_outlets("entrust", ENTRUST_ACTIONS.keys))
  end

  def entrust_cell_label(copy)
    [ copy.title, t("catalog.rarity.#{copy.rarity}"), t("market.entrustments.new.season", number: copy.season_number),
      picoins_label(copy.value), t("market.entrustments.new.free", count: copy.free) ].join(", ")
  end

  def entrust_line_stepper
    { value: 1, max: 2, label: "", value_text: "", max_text: "", max_phone_text: "" }
  end

  def entrust_cell_stepper(copy, copies)
    max = copy.free
    { value: copies, max:, label: t("market.entrustments.strings.quantity_label", title: copy.title),
      value_text: t("market.entrustments.strings.value_text", count: copies, max:),
      max_text: t("market.entrustments.strings.max", max:), max_phone_text: t("market.entrustments.strings.max_phone", max:) }
  end
end
