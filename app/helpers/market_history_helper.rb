module MarketHistoryHelper
  def history_line_text(line, viewer)
    case line.kind
    when :bid then render(PlayerNameComponent.new(player: line.player, viewer:))
    when :covered then t("market.listings.history.covered_html", leader: render(PlayerNameComponent.new(player: line.leader, viewer:)),
      name: render(PlayerNameComponent.new(player: line.player, viewer:)), amount: outcome_amount(line.price))
    when :extension then t("market.listings.history.extension_html", time: local_time_tag(line.until))
    when :raise then t("market.listings.history.raise_html", name: render(PlayerNameComponent.new(player: line.player, viewer:)))
    when :voided then t("market.listings.history.voided")
    when :created then t("market.listings.history.created_html", name: render(PlayerNameComponent.new(player: line.player, viewer:)))
    end
  end

  def outcome_body(outcome, viewer)
    name = render(PlayerNameComponent.new(player: outcome.winner, viewer:)) if outcome.winner
    amounts = { name:, card: outcome.card.title, price: outcome_amount(outcome.price), received: outcome_amount(outcome.received),
      surplus: outcome_amount(outcome.surplus) }
    case outcome.kind
    when :won then t(outcome.surplus.positive? ? "market.listings.outcome.won.body_surplus_html" : "market.listings.outcome.won.body_html", **amounts)
    when :lost then t("market.listings.outcome.lost.body_html", **amounts)
    when :viewer_sold then t("market.listings.outcome.viewer.body_html", **amounts)
    when :seller_sold then t("market.listings.outcome.seller.body_html", **amounts)
    when :no_bid then t("market.listings.outcome.no_bid.body")
    when :cancelled then t("market.listings.outcome.cancelled.body")
    when :withdrawn then t("market.listings.outcome.withdrawn.body")
    end
  end

  def outcome_title(outcome)
    case outcome.kind
    when :won then t("market.listings.outcome.won.title", card: outcome.card.title.upcase)
    when :lost then t("market.listings.outcome.lost.title")
    when :viewer_sold then t("market.listings.outcome.viewer.title")
    when :seller_sold then t("market.listings.outcome.seller.title")
    when :no_bid then t("market.listings.outcome.no_bid.title")
    when :cancelled then t("market.listings.outcome.cancelled.title")
    when :withdrawn then t("market.listings.outcome.withdrawn.title")
    end
  end

  def outcome_tone(outcome)
    case outcome.kind
    when :won, :seller_sold then "success"
    when :cancelled, :withdrawn then "alert"
    else "neutral"
    end
  end

  private
    def outcome_amount(amount) = amount && render(PicoinAmountComponent.new(amount:))
end
