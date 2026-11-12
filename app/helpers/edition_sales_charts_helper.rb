module EditionSalesChartsHelper
  MILLISECONDS = 1_000

  def edition_sales_drawing(chart)
    Charts::Drawing.new(
      kind: "edition_sales", title: t("charts.edition_sales.title"), summary: edition_sales_summary(chart),
      labels: chart.sales.map { chart_day(it.sold_at.utc.to_date) }, x: chart.sales.map { (it.sold_at.to_f * MILLISECONDS).round },
      series: edition_sales_series(chart), words: edition_sales_words(chart), legend: edition_sales_legend(chart),
      table: Charts::Table.new(
        caption: t("charts.edition_sales.caption"),
        columns: %i[day sale average].map { t("charts.edition_sales.columns.#{it}") },
        rows: chart.sales.map do |sale|
          Charts::Row.new(day: sale.sold_at.utc.to_date, cells: [ chart_picoins(sale.final_price), chart_picoins((sale.average_after_sale if chart.averaged?)) ])
        end
      )
    )
  end

  private
    def edition_sales_series(chart)
      series = { chart.rarity => chart.sales.map(&:final_price) }
      series[:average] = chart.sales.map(&:average_after_sale) if chart.averaged?
      series.merge(floor: Array.new(chart.count, chart.floor))
    end

    def edition_sales_words(chart)
      { series: { chart.rarity => t("charts.edition_sales.legend.sale"), average: t("charts.edition_sales.legend.average"), floor: edition_floor_label(chart) },
        tooltip: t("charts.edition_sales.tooltip") }
    end

    def edition_sales_legend(chart)
      [
        [ chart.rarity, t("charts.edition_sales.legend.sale"), Catalog::Rarity::TIERS.key(chart.rarity) ],
        ([ :average, t("charts.edition_sales.legend.average") ] if chart.averaged?),
        [ :floor, edition_floor_label(chart) ]
      ].compact
    end

    def edition_floor_label(chart)
      t("charts.edition_sales.legend.floor", rarity: t("catalog.rarity.#{chart.rarity}"), amount: picoins(chart.floor))
    end

    def edition_sales_summary(chart)
      return t("charts.edition_sales.empty", window: chart.window_days) if chart.count.zero?

      last = picoins(chart.last_sale.final_price)
      return t("charts.edition_sales.few_sales", count: chart.count, window: chart.window_days, last:) unless chart.averaged?

      average = chart.last_average ? picoins(chart.last_average) : t("charts.missing_spoken")
      t("charts.edition_sales.summary", count: chart.count, window: chart.window_days, last:, average:)
    end
end
