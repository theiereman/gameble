module Game
  module DuelsDue
    OPEN = "state IN ('challenged', 'active')".freeze
    DEADLINE_PASSED = <<~SQL.squish.freeze
      move_deadline_at <= :now OR EXISTS (
        SELECT 1 FROM game_duel_seats WHERE duel_id = game_duels.id AND present_until <= :lapsed_lease)
    SQL

    def self.call(now)
      candidates = Duel.where(OPEN).where(DEADLINE_PASSED, now:, lapsed_lease: now - DuelClock::ABSENCE).includes(:seats, :rounds)
      candidates.select { DuelClock.new(it, it.seats, DuelRules.new(it, it.rounds.to_a)).due?(now) }.map(&:token)
    end
  end
end
