module MarketHealthHelper
  SHARES = %i[destroyed_share top_share].freeze

  def health_value(indicator, value)
    return t("back_office.market_health.no_value") if value.nil?

    case indicator.to_sym
    when *SHARES then health_share(value)
    when :picoins_per_player then picoins(value, compact: true)
    else health_days(value)
    end
  end

  def health_share(basis_points) = number_to_percentage(basis_points / 100.0, precision: 1, strip_insignificant_zeros: true)

  def health_days(days) = t("back_office.market_health.days", value: number_with_precision(days, precision: 1, strip_insignificant_zeros: true))

  def health_age(seconds) = distance_of_time_in_words(0, seconds, include_seconds: true)

  def health_day(day) = l(day, format: day.day == 1 ? :long_day_first : :long_day)

  def health_rarity_name(rarity) = t("catalog.rarity.#{rarity}")
end
