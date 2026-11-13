module MarketCopyGridHelper
  def copy_matches(count) = t("market.copy_filters.matches", count:, number: number_with_delimiter(count))
end
