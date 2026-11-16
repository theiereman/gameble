module Game
  class AcceptChallenge < Operation
    include DuelSteps

    def call(player:, token:, deck_token:, move_number:)
      player = step require_player(player)
      move_number = step whole_number(move_number)
      duel = step seated_duel(player, token)

      transaction do
        duel, seats = lock_duel(duel)
        step invited(duel, seats, player, move_number)
        step not_seated(player)
        step friends_to_duel(player, seats[:challenger].player_id)
        decks = [ ready_deck(seats[:challenger].player_id, seats[:challenger].deck_token), ready_deck(player.id, deck_token) ]
        step(decks.all?(&:success?) ? start(player, duel, seats, decks.map(&:value!), deck_token) : lapse(player, duel, seats))
      end
      step duel.started? ? Success(duel) : Failure(:deck_not_ready)
    end

    private

    def invited(duel, seats, player, move_number)
      seat = seats[:opponent]
      turn = duel.state == "challenged" && duel.move_number == move_number && seat.player_id == player.id && seat.status == "invited"
      turn ? Success() : Failure(:not_your_move)
    end

    def start(player, duel, seats, decks, deck_token)
      cards = DuelRules::ROLES.zip(decks).to_h { |role, deck| [ role, DuelSnapshot.call(deck) ] }
      duel.update!(state: "active", started_at: Time.current, first_caller: DuelRules::ROLES.sample(random: SecureRandom).to_s,
        move_number: next_move(duel), **cards.to_h { |role, deck| [ :"#{role}_cards", deck.map(&:to_snapshot) ] },
        **cards.to_h { |role, deck| [ :"#{role}_draw_order", deck.map(&:card_season_id).shuffle(random: SecureRandom) ] })
      seats[:opponent].update!(status: "seated", deck_token:)
      duel_published(DuelChallengeAccepted, player, duel, seats)
    end

    def lapse(player, duel, seats)
      duel.update!(state: "lapsed", ended_at: Time.current, move_number: next_move(duel))
      leave(seats)
      duel_published(DuelChallengeLapsed, player, duel, seats)
    end
  end
end
