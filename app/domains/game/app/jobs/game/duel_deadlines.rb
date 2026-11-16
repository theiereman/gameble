module Game
  module DuelDeadlines
    def self.settle(token, move_number = nil)
      duel = DuelByToken.call(token)
      return if duel.nil? || (move_number && duel.move_number != move_number)

      clock = DuelClock.new(duel, duel.seats, DuelRules.new(duel, duel.rounds.to_a))
      return unless clock.open? && (mover = Accounts::PlayerById.call(clock.mover_seat&.player_id))

      operation = duel.state == "challenged" ? LapseChallenge : PlayAutomaticMove
      operation.new.call(player: mover, token:, move_number: duel.move_number)
    end
  end
end
