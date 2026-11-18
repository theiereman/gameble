module Game
  class DuelClock
    ACCEPT = 60.seconds
    CALL = 60.seconds
    ANSWER = 45.seconds
    JOB_DELAY = 2.seconds
    ABSENCE = 60.seconds
    PRACTICE = 30.minutes

    def initialize(duel, seats, rules = nil)
      @duel = duel
      @seats = seats
      @rules = rules
    end

    def open? = %w[challenged active].include?(@duel.state)

    def mover
      return :opponent if @duel.state == "challenged"

      @rules.pending ? @rules.answerer : @rules.caller
    end

    def mover_seat = @seats.find { it.role == mover.to_s }

    def deadline
      lease = mover_seat&.present_until
      [ @duel.move_deadline_at, lease && lease + ABSENCE ].compact.min
    end

    def due?(now)
      at = open? && deadline
      at.present? && at <= now
    end
  end
end
