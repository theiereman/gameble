module Game
  class CallRound < Operation
    include DuelSteps

    def call(player:, token:, move_number:, card:, stat:, direction:, automatic: false)
      step require_player(player) unless automatic
      move_number = step whole_number(move_number)
      position = step whole_number(card)
      stat = step known_stat(stat)
      direction = step known_direction(direction)
      duel = step seated_duel(player, token)

      transaction do
        duel, seats = lock_duel(duel)
        role = step role_of(seats, player)
        rules = DuelRules.new(duel, duel.rounds.to_a)
        step calling(duel, rules, role, move_number)
        card = step card_in_hand(rules, role, position)
        step uncalled(rules, role, stat)
        round = DuelRound.create!(duel_id: duel.id, number: rules.round, caller: role.to_s, caller_card_season_id: card.card_season_id,
          stat: stat.to_s, direction: direction.to_s, caller_value: snapshot_value(card, stat), called_at: Time.current,
          caller_automatic: automatic)
        duel.update!(move_number: next_move(duel), move_deadline_at: schedule(duel, next_move(duel), DuelClock::ANSWER))
        step round_published(DuelRoundCalled, player, duel, round.number)
        duel
      end
    end

    private

    def calling(duel, rules, role, move_number)
      playing(duel, move_number) && rules.pending.nil? && rules.caller == role ? Success() : Failure(:not_your_move)
    end

    def uncalled(rules, role, stat)
      rules.stats_left(role).include?(stat) ? Success() : Failure(:stat_already_called)
    end
  end
end
