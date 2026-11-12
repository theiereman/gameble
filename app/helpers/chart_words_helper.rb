module ChartWordsHelper
  MINUTES_PER_HOUR = 60
  MINUTES_PER_DAY = 1_440

  def chart_missing = spoken_as(t("charts.missing"), t("charts.missing_spoken"))

  def chart_picoins(amount) = amount.nil? ? chart_missing : picoins(amount)

  def chart_compact_picoins(amount) = amount.nil? ? chart_missing : spoken_as(picoins(amount, compact: true), spoken_picoins(amount))

  def chart_signed_picoins(amount)
    return chart_missing if amount.nil?
    return spoken_as("+#{picoins(amount)}", t("charts.spoken.plus", amount: picoins(amount))) if amount.positive?
    return picoins(0) if amount.zero?

    spoken_as("−#{picoins(-amount)}", t("charts.spoken.minus", amount: picoins(-amount)))
  end

  def chart_share(basis_points) = basis_points.nil? ? chart_missing : chart_share_words(basis_points)

  def chart_share_words(basis_points)
    return t("charts.missing_spoken") if basis_points.nil?

    number_to_percentage(basis_points / 100.0, precision: 1, strip_insignificant_zeros: true)
  end

  def chart_duration(days)
    return chart_missing if days.nil?

    minutes = (days * MINUTES_PER_DAY).round
    if minutes < MINUTES_PER_HOUR then minutes_forms(minutes)
    elsif minutes < MINUTES_PER_DAY then hours_forms(*minutes.divmod(MINUTES_PER_HOUR))
    else days_forms(days)
    end
  end

  def spoken_picoins(amount)
    number, _suffix, unit, value = compact_picoins_parts(amount)
    unit ? t("charts.spoken.#{unit}", number:, count: plural_count(value)) : picoins_label(amount)
  end

  def chart_day(day) = l(day, format: :chart_day)

  private
    def spoken_as(shown, spoken) = safe_join([ tag.span(shown, aria: { hidden: true }), tag.span(spoken, class: "visually-hidden") ])

    def minutes_forms(minutes)
      spoken_as(t("charts.duration.minutes", count: minutes), t("charts.duration.minutes_spoken", count: minutes))
    end

    def hours_forms(hours, minutes)
      minutes = format("%02d", minutes)
      spoken_as(t("charts.duration.hours", hours:, minutes:), t("charts.duration.hours_spoken", count: hours, minutes:))
    end

    def days_forms(days)
      value = number_with_precision(days, precision: 1, strip_insignificant_zeros: true)
      spoken_as(t("charts.duration.days", value:), t("charts.duration.days_spoken", count: plural_count(days), value:))
    end

    def plural_count(value) = value >= 1 && value < t("charts.one_below") ? 1 : value
end
