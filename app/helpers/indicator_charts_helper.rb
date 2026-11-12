module IndicatorChartsHelper
  UNITS = { destroyed_share: :share, top_share: :share, picoins_per_player: :picoins, days_of_income: :days }.freeze
  TARGETED = %i[days_of_income].freeze

  def indicator_rarities = [ :epic, *(Catalog::Rarity::TIERS.values - [ :epic ]) ]

  def indicator_drawing(key, indicator, days, rarity: nil)
    unit = UNITS.fetch(key)
    title = t("charts.indicators.#{key}.title", rarity: (health_rarity_name(rarity) if rarity))
    series = { value: indicator.values.map { drawn(unit, it) } }
    series[:threshold] = indicator.threshold.map { drawn(unit, it) } if indicator.threshold
    Charts::Drawing.new(
      kind: "indicator_#{unit}", title:, summary: indicator_summary(key, indicator, title), labels: chart_labels(days), series:,
      words: indicator_words(key, unit, indicator, title), legend: (indicator_legend(key, indicator, title) if indicator.threshold) || [],
      table: Charts::Table.new(
        caption: title,
        columns: [ t("charts.indicators.columns.day"), title, *(threshold_name(key) if indicator.threshold) ],
        rows: days.each_index.map do |index|
          Charts::Row.new(day: days[index], cells: [ indicator_cell(key, indicator.values[index]), *(indicator_cell(key, indicator.threshold[index]) if indicator.threshold) ])
        end
      )
    )
  end

  private
    def drawn(unit, value) = unit == :share && value ? value / 100.0 : value

    def indicator_cell(key, value) = value.nil? ? chart_missing : health_value(key, value)

    def threshold_name(key) = t(TARGETED.include?(key) ? "charts.indicators.target_name" : "charts.indicators.alert_name")

    def threshold_label(key, indicator)
      t(TARGETED.include?(key) ? "charts.indicators.target" : "charts.indicators.alert", value: health_value(key, indicator.last_threshold))
    end

    def indicator_words(key, unit, indicator, title)
      words = { tick: t("charts.indicators.ticks.#{unit}"), tooltip: t("charts.indicators.tooltip"), series: { value: title } }
      return words unless indicator.threshold

      words.merge(series: { value: title, threshold: threshold_name(key) }, threshold: threshold_label(key, indicator))
    end

    def indicator_legend(key, indicator, title) = [ [ :value, title ], [ :threshold, threshold_label(key, indicator) ] ]

    def indicator_summary(key, indicator, title)
      value = indicator.values.compact.last
      return t("charts.indicators.no_value", indicator: title) if value.nil?

      threshold = if indicator.threshold
        t(TARGETED.include?(key) ? "charts.indicators.target_phrase" : "charts.indicators.alert_phrase", value: health_value(key, indicator.last_threshold))
      else
        t("charts.indicators.no_threshold")
      end
      t("charts.indicators.summary", indicator: title, value: health_value(key, value), threshold:)
    end
end
