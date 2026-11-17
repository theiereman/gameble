module Game
  module DuelCapsule
    GRANTED = "granted".freeze
    AUTOMATIC_MOVE = "automatic_move".freeze
    ALREADY_WON_TODAY = "already_won_today".freeze

    INDEX = "index_game_packs_one_duel_pack_per_day".freeze

    def self.award(rules, seats, now, random: SecureRandom)
      winner_role = rules.result
      return if winner_role == :draw

      winner = Accounts::Player.find_by(id: seats.fetch(winner_role).player_id)
      return if winner.nil? || winner.removed?
      return AUTOMATIC_MOVE if automatic_move_of?(rules, winner_role)

      BankLock.acquire(winner.id)
      pool = DrawPool.current
      return if pool.nil?

      grant(winner, pool, now, random) ? GRANTED : ALREADY_WON_TODAY
    end

    def self.automatic_move_of?(rules, role)
      rules.revealed.any? do |round|
        round.caller.to_sym == role ? round.caller_automatic : round.answer_automatic
      end
    end

    def self.grant(player, pool, now, random)
      row = Pack.row(player_id: player.id, kind: :duel, season_id: pool.season_id, available_at: now,
        card_season_ids: Draw.pack(odds: DrawOdds::DUEL, size: Pack::DUEL_SIZE, random:, pool:))
      Pack.insert(row.merge(duel_day: DailyBonusClaim.day_of(now)), unique_by: INDEX).rows.any?
    end

    private_class_method :automatic_move_of?, :grant
  end
end
