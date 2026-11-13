module MarketSalesHelper
  SALE_ACTIONS = {
    "copy-filters" => {},
    "listing-grid" => { chosen: :chosen, clear: :clear },
    "listing-fields" => { typed: :typed, entered: :entered, duration: :duration, back: :back },
    "listing-summary" => {}
  }.freeze
  SALE_SUBMIT_ACTION = "submit->listing-form#submit".freeze

  SALE_REFUSAL_SLOTS = {
    start_below_minimum: :starting_price,
    stamp_not_covered: :stamp,
    invalid_duration: :duration,
    copy_not_free: :grid,
    no_rarity: :grid,
    market_closed: :closed,
    player_required: :signed_out
  }.freeze

  WHOLE_DAYS_FROM_HOURS = 48

  def sale_root_data(open:, basis_points:, available:)
    { controller: "listing-form", action: "#{screen_actions("listing-form", SALE_ACTIONS)} #{SALE_SUBMIT_ACTION}",
      listing_form_locale_value: I18n.locale, listing_form_basis_points_value: basis_points, listing_form_open_value: open,
      listing_form_available_value: available,
      listing_form_strings_value: screen_strings("market.sales.strings") }
      .merge(screen_outlets("listing-form", SALE_ACTIONS.keys))
  end

  def sale_edition_data(copy, settings)
    rarity = copy.card.rarity.to_sym
    { ref: copy.ref, title: copy.card.title, rarity:, rarity_name: sale_rarity_name(rarity), season: copy.card.season_number,
      free: copy.free, minimum: settings.minimum_price(rarity), stamp: settings.stamp(rarity) }
  end

  def sale_stamp_short_text(missing)
    t("market.sales.strings.stamp_short", amount: picoins([ missing, 1 ].max))
  end

  def sale_cell_label(copy, settings, price = nil)
    minimum = picoins_label(settings.minimum_price(copy.card.rarity.to_sym))
    [ copy.card.title, t("catalog.rarity.#{copy.card.rarity}"), t("market.sales.new.season", number: copy.card.season_number),
      t("market.sales.new.free", count: copy.free), t("market.sales.new.cell_minimum", amount: minimum), average_price_words(price) ].compact.join(", ")
  end

  def sale_durations(settings, checked:)
    [ settings.duration_short_hours, settings.duration_medium_hours, settings.duration_long_hours ].map do |hours|
      { hours:, label: sale_duration_label(hours), checked: checked.to_s == hours.to_s }
    end
  end

  def sale_refusal_slot(code, invalid_price_at: nil)
    return invalid_price_at || :starting_price if code == :invalid_price

    SALE_REFUSAL_SLOTS.fetch(code, :form)
  end

  def sale_rarity_name(rarity) = CardStrings.new.rarity_name(rarity).downcase

  private
    def sale_duration_label(hours)
      return t("market.sales.new.duration_days", count: hours / 24) if hours >= WHOLE_DAYS_FROM_HOURS && (hours % 24).zero?

      t("market.sales.new.duration_hours", count: hours)
    end
end
