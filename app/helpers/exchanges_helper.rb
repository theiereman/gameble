module ExchangesHelper
  def kept_exchanges_tab
    @kept_exchanges_tab ||= Game::ExchangesTab.call(current_player)
  end

  def exchanges_badge_suffix(waiting:, outbid:)
    parts = [
      (t("shell.exchanges.trades", count: waiting, number: number_with_delimiter(waiting)) if waiting.positive?),
      (t("shell.exchanges.auctions", count: outbid, number: number_with_delimiter(outbid)) if outbid.positive?)
    ].compact
    case parts
    in [ trades, auctions ] then t("shell.exchanges.to_see_both", trades:, auctions:)
    in [ part ] then t("shell.exchanges.to_see_one", part:)
    in [] then ""
    end
  end

  def count_badge(count, spoken, class:)
    return unless count.positive?

    safe_join([ tag.span(spoken, class: "visually-hidden"), tag.span(number_with_delimiter(count), class:, aria: { hidden: true }) ])
  end
end
