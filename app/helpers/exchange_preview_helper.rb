module ExchangePreviewHelper
  Preview = Data.define(:prices, :reactor) do
    def prices? = !prices.nil?

    def reactor? = !reactor.nil? && !reactor.empty?

    def priced? = prices? && !prices.empty?
  end

  def exchange_preview_cache_key
    [ "market-exchange-preview", I18n.locale, ChartVersions::SnapshotDated.current.version, *exchange_preview_kinds ]
  end

  def exchange_preview
    through = ChartVersions::SnapshotDated.current.drawn_through
    Preview.new(
      prices: (Game::Market::EconomySeries.rarity_prices(through:) if exchange_preview_kinds.include?("rarity_prices")),
      reactor: (Game::Market::EconomySeries.reactor(through:) if exchange_preview_kinds.include?("reactor"))
    )
  end

  def exchange_preview_change(prices, rarity)
    change = prices.change_basis_points(rarity)
    trend = if change.nil? || change.zero? then "flat" elsif change.positive? then "up" else "down" end
    tag.span(chart_signed_share(change), class: "exchange-preview__change exchange-preview__change--#{trend}")
  end

  private
    def exchange_preview_kinds
      @exchange_preview_kinds ||= Game::Market::ChartPublications.visible_kinds(current_player) & Game::Market::ChartPublications::EXCHANGE_KINDS
    end
end
