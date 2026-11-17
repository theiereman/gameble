module DuelsHelper
  MARGIN_SIGNS = { 1 => "+", -1 => "−" }.freeze
  MARGIN_WORDS = { 1 => :plus, -1 => :minus }.freeze

  def duel_reachable(friend)
    @reachable_friends ||= Game::ReachableFriends.call(current_player).index_by { it.player.id }
    @reachable_friends[friend.id]
  end

  def duel_player_name(player)
    return tag.span(t("player_name.anonymous"), class: "player-name player-name--anonymous") if player.nil?

    render PlayerNameComponent.new(player:, viewer: nil, linked: false)
  end

  def duel_plain_name(player)
    return t("player_name.anonymous") if player.nil? || player.removed?

    Accounts::PersonaName.clean(player.persona_name) || t("shell.player.fallback_name")
  end

  def duel_card_profile(card, stat)
    held = card.stat(stat)
    Game::DuelProfiles::Stat.new(name: stat, value: held.value, percentile: held.percentile, median_distance: held.median_distance,
      weekly_percentile: nil)
  end

  def duel_card_value(card, stat)
    profile = duel_card_profile(card, stat)
    profile.value.nil? ? t("duel_stats.no_value") : duel_stat_value(profile)
  end

  def duel_card_words(card, stat)
    profile = duel_card_profile(card, stat)
    profile.percentile.nil? ? t("duel_stats.no_value") : duel_stat_words(profile, rarity: Catalog::Rarity::TIERS.fetch(card.rarity))
  end

  def duel_stat_label(card, stat, open: true)
    label = t("duels.board.stat_label", name: t("duel_stats.names.#{stat}"), words: duel_card_words(card, stat), value: duel_card_value(card, stat))
    open ? label : t("duels.board.stat_called", label:)
  end

  def duel_card_name(screen, card) = t("duels.board.card_name", title: screen.title(card), year: screen.card_view(card).year)

  def duel_direction(stat, direction) = t("duel_stats.directions.#{stat}.#{direction}")

  def duel_direction_inline(stat, direction)
    words = duel_direction(stat, direction)
    t("duels.board.directions_lowercase") ? words.downcase_first : words
  end

  def duel_stat_names(stats) = stats.map { t("duel_stats.names.#{it}") }.join(", ")

  def duel_points(margin) = number_with_precision(margin.abs, precision: 1, strip_insignificant_zeros: true)

  def duel_signed_margin(margin) = "#{MARGIN_SIGNS[margin <=> 0]}#{duel_points(margin)}"

  def duel_round_spoken(screen) = t("duels.board.round_spoken", number: screen.round)

  def duel_score_spoken(screen) = t("duels.board.score_spoken", score: screen.score, other_score: screen.other_score)

  def duel_margin_spoken(margin) = t("duels.board.margin_spoken.#{MARGIN_WORDS.fetch(margin <=> 0, :even)}", points: duel_points(margin))

  def duel_announcement(screen)
    return unless screen.turn == :answer

    t("duels.board.called_status", name: duel_plain_name(screen.opponent), card: screen.title(screen.current_call.card))
  end

  def duel_turn(screen)
    case screen.turn
    when :call, :answer then t("duels.board.turn.#{screen.turn}")
    when :their_call, :their_answer then t("duels.board.turn.#{screen.turn}_html", name: duel_player_name(screen.opponent))
    end
  end

  def duel_clock_name(screen) = screen.clock_mine? ? t("duels.clock.you") : duel_player_name(screen.opponent)

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

  def duel_round_line(screen, reveal)
    caller = reveal.called ? screen.viewer : screen.opponent
    t("duels.board.round_line", number: reveal.number, name: duel_plain_name(caller), direction: duel_direction_inline(reveal.stat, reveal.direction),
      card: duel_card_name(screen, reveal.caller_card), other_card: duel_card_name(screen, reveal.answer_card),
      outcome: t("duels.board.outcome.#{reveal.outcome}"))
  end

  def duel_result_spoken(screen)
    spoken = t("duels.board.result_spoken.#{screen.outcome}", name: duel_plain_name(screen.opponent), score: screen.score,
      other_score: screen.other_score)
    screen.decided_on_margin? ? spoken + t("duels.board.result_margin", margin: duel_points(screen.margin_gap)) : spoken
  end

  def duel_result(screen)
    t("duels.board.result.#{screen.outcome}_html", name: duel_player_name(screen.opponent),
      score: tag.span(screen.score, class: "duel-result__figure"), other_score: tag.span(screen.other_score, class: "duel-result__figure"))
  end
end
