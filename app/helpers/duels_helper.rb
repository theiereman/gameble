module DuelsHelper
  MARGIN_SIGNS = { 1 => "+", -1 => "−" }.freeze

  def duel_reachable(friend)
    @reachable_friends ||= Game::ReachableFriends.call(current_player).index_by { it.player.id }
    @reachable_friends[friend.id]
  end

  def duel_player_name(player)
    return tag.span(t("player_name.anonymous"), class: "player-name player-name--anonymous") if player.nil?

    render PlayerNameComponent.new(player:, viewer: nil, linked: false)
  end

  def duel_card_value(card, stat)
    value = card.stat(stat).value
    return t("duel_stats.no_value") if value.nil?

    duel_stat_value(Game::DuelProfiles::Stat.new(name: stat, value:, percentile: nil, median_distance: nil, weekly_percentile: nil))
  end

  def duel_direction(stat, direction) = t("duel_stats.directions.#{stat}.#{direction}")

  def duel_stat_names(stats) = stats.map { t("duel_stats.names.#{it}") }.join(", ")

  def duel_points(margin) = number_with_precision(margin.abs, precision: 1, strip_insignificant_zeros: true)

  def duel_signed_margin(margin) = "#{MARGIN_SIGNS[margin <=> 0]}#{duel_points(margin)}"

  def duel_turn(screen)
    case screen.turn
    when :call, :answer then t("duels.board.turn.#{screen.turn}")
    when :their_call, :their_answer then t("duels.board.turn.#{screen.turn}_html", name: duel_player_name(screen.opponent))
    end
  end

  def duel_waiting(screen)
    name = duel_player_name(screen.opponent)
    return t("duels.board.ended") unless screen.waiting?

    screen.challenger? ? t("duels.lobby.waiting_html", name:) : t("duels.lobby.received_html", name:)
  end

  def duel_reveal(screen, reveal)
    t("duels.board.reveal.#{reveal.outcome}", number: reveal.number, card: screen.title(reveal.mine),
      value: duel_card_value(reveal.mine, reveal.stat), other_card: screen.title(reveal.theirs),
      other_value: duel_card_value(reveal.theirs, reveal.stat), direction: duel_direction(reveal.stat, reveal.direction),
      score: reveal.score, other_score: reveal.other_score)
  end

  def duel_result(screen)
    t("duels.board.result.#{screen.outcome}_html", name: duel_player_name(screen.opponent), score: screen.score,
      other_score: screen.other_score)
  end
end
