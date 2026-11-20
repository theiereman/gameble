module Game
  class StartPracticeDuel < Operation
    include DuelSteps

    def call(player:, deck_token:)
      player = step require_player(player)

      transaction do
        bot = PracticeBot.player_for(player)
        TradeLocks.players(player.id, bot.id)
        step idle(player)
        step idle(bot)
        deck = step ready_deck(player.id, deck_token)
        archetype = PracticeBot.archetype_after(player)
        cards = { challenger: DuelSnapshot.call(deck), opponent: DuelSnapshot.for_cards(PracticeBot.deck_cards(archetype)) }
        step(cards.values.all? { it.size == PracticeBot::DECK_SIZE } ? Success() : Failure(:deck_not_ready))
        start(player, bot, deck_token, cards, archetype)
      end
    end

    private

    def start(player, bot, deck_token, cards, archetype)
      duel = Duel.new(practice: true, bot_archetype: archetype)
      duel.update!(state: "active", rules_version: DuelRules::VERSION, started_at: Time.current,
        first_caller: DuelRules::ROLES.sample.to_s, move_number: 1, move_deadline_at: schedule(duel, 1, DuelClock::CALL),
        **cards.to_h { |role, deck| [ :"#{role}_cards", deck.map(&:to_snapshot) ] },
        **cards.to_h { |role, deck| [ :"#{role}_draw_order", deck.map(&:card_season_id).shuffle(random: SecureRandom) ] })
      seats = {
        challenger: DuelSeat.create!(duel_id: duel.id, role: "challenger", player_id: player.id, deck_token:, status: "seated"),
        opponent: DuelSeat.create!(duel_id: duel.id, role: "opponent", player_id: bot.id, status: "seated")
      }
      step duel_published(DuelChallengeAccepted, player, duel, seats)
      duel
    end
  end
end
