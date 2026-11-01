module TradeSuggestionsHelper
  Prefill = Data.define(:friend, :take, :give) do
    def lines(side) = public_send(side).map { Game::TradesOf::Line.new(card_season_id: it, quantity: 1) }

    def shows?(suggestion)
      suggestion.player == friend && give.empty? && suggestion.card_season_ids.sort == take.sort
    end
  end

  def trade_suggestion_goal_name(goal)
    t("trades.suggestions.goal", number: goal.position, set: goal_set_name(goal))
  end

  def trade_suggestion_summary(suggestion, cards)
    t("trades.suggestions.summary_open", cards: trade_suggestion_titles(suggestion, cards).join(", "), name: friend_name(suggestion.player))
  end

  def trade_suggestion_opener_name(suggestion, cards, goals)
    by_position = goals.index_by(&:position)
    named = suggestion.lines.filter_map do |line|
      view = cards[line.card_season_id] or next
      served = line.goal_positions.filter_map { by_position[it] }.map { trade_suggestion_goal_name(it) }
      t("trades.suggestions.card", title: view.title, goals: served.join(", "))
    end
    t("trades.suggestions.label_open", name: friend_name(suggestion.player), cards: named.join(", "), presence: presence_text(suggestion.friend))
  end

  def trade_suggestion_send_name(suggestion)
    t("trades.suggestions.send_label", name: friend_name(suggestion.player))
  end

  def trade_suggestion_opener_path(suggestion, cards)
    new_trade_path(friend: suggestion.player.token, take: trade_suggestion_keys(suggestion.lines, cards),
      give: trade_suggestion_keys(suggestion.own_lines, cards).presence)
  end

  def trade_suggestion_send_params(suggestion, cards, position:)
    { friend: suggestion.player.token, position:,
      take: trade_suggestion_quantities(suggestion.lines, cards), give: trade_suggestion_quantities(suggestion.own_lines, cards) }.compact_blank
  end

  def trade_suggestion_current?(suggestion, prefill)
    prefill.present? && prefill.shows?(suggestion)
  end

  def trade_suggestion_focus(sent, suggestions)
    return {} unless sent.is_a?(Hash)

    position = sent["position"]
    position.is_a?(Integer) && position < suggestions.size ? { suggestion: position } : { trade: sent["trade"] }
  end

  private
    def trade_suggestion_titles(suggestion, cards)
      suggestion.lines.filter_map { cards[it.card_season_id]&.title }
    end

    def trade_suggestion_keys(lines, cards)
      lines.filter_map { (view = cards[it.card_season_id]) && trade_card_key(view) }
    end

    def trade_suggestion_quantities(lines, cards)
      trade_suggestion_keys(lines, cards).index_with(1)
    end
end
