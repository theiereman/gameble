module RarityPricesChartsHelper
  SPARKLINE_MINIMUM_POINTS = 2

  Tile = Data.define(:rarity, :tier, :name, :price, :change, :sparkline)

  def rarity_price_tiles(prices)
    prices.rarities.map do |rarity|
      Tile.new(rarity:, tier: Catalog::Rarity::TIERS.key(rarity), name: rarity_name(rarity),
        price: chart_duration(prices.last_days_of_income(rarity)), change: rarity_price_change(prices, rarity),
        sparkline: rarity_sparkline_drawing(prices, rarity))
    end
  end

  def rarity_index_drawing(prices)
    Charts::Drawing.new(
      kind: "rarity_index", title: t("charts.rarity_prices.index.title"), summary: rarity_index_summary(prices),
      labels: chart_labels(prices.days), series: prices.index,
      words: { series: prices.rarities.index_with { rarity_name(it) }, tooltip: t("charts.rarity_prices.tooltip") },
      legend: prices.rarities.map { [ it, rarity_legend_label(prices, it), Catalog::Rarity::TIERS.key(it) ] },
      table: Charts::Table.new(
        caption: t("charts.rarity_prices.index.caption"),
        columns: [ t("charts.rarity_prices.columns.day"), *prices.rarities.map { rarity_name(it) } ],
        rows: prices.days.each_index.map do |index|
          Charts::Row.new(day: prices.days[index], cells: prices.rarities.map { chart_index(prices.index[it][index]) })
        end
      )
    )
  end

  def rarity_sparkline_drawing(prices, rarity)
    values = prices.days_of_income.fetch(rarity)
    return if values.compact.size < SPARKLINE_MINIMUM_POINTS

    Charts::Drawing.new(kind: "sparkline", labels: chart_labels(prices.days), series: { rarity => values })
  end

  def chart_index(value) = value.nil? ? chart_missing : number_with_precision(value, precision: 1, strip_insignificant_zeros: true)

  private
    def rarity_name(rarity) = t("catalog.rarity.#{rarity}")

    def rarity_price_change(prices, rarity)
      change = prices.change_basis_points(rarity)
      change.nil? ? chart_missing : t("charts.rarity_prices.change_html", change: chart_signed_share(change))
    end

    def rarity_legend_label(prices, rarity)
      last = prices.last_index(rarity)
      last.nil? ? rarity_name(rarity) : t("charts.rarity_prices.index.legend", rarity: rarity_name(rarity), index: chart_index(last))
    end

    def rarity_index_summary(prices)
      rarity = prices.highest_index_rarity
      return t("charts.rarity_prices.empty") if rarity.nil?

      t("charts.rarity_prices.index.summary", rarity: rarity_name(rarity), days: chart_duration_words(prices.last_days_of_income(rarity)),
        index: chart_index(prices.last_index(rarity)))
    end
end
