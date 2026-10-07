module Accounts
  # A player reports another player's username or profile (CAP-15, AD-14),
  # with one of four reasons: "inappropriate_name", "cheating", "harassment"
  # or "other". It is anonymous to the reported player: nothing is published
  # to them and the result names no one. Reusable: the public profile and the
  # friend profile (epic 5) both call it. A player may report each other
  # player once (a repeat succeeds and adds nothing, so the answer cannot
  # tell) and at most LIMIT players per PERIOD. Housekeeping: it publishes no
  # event (AD-10).
  #
  #   Accounts::ReportPlayer.new.call(reporter:, reported:, reason: "cheating")
  #   # => Success(report) | Failure(:player_required | :player_not_found |
  #   #    :cannot_report_self | :invalid_reason | :rate_limited)
  class ReportPlayer < ApplicationOperation
    LIMIT = 5
    PERIOD = 1.day

    def call(reporter:, reported:, reason:)
      reporter = step require_reporter(reporter)
      reported = step require_reported(reporter, reported)
      reason = step check(reason)

      transaction do
        # Serializes one reporter's reports, so the daily limit cannot be raced.
        reporter.lock!
        existing = Report.find_by(reporter:, reported:)
        next existing if existing

        step within_limit(reporter)
        Report.create!(reporter:, reported:, reason:)
      end
    rescue ActiveRecord::RecordNotUnique
      # A double click raced this one: the other report stands.
      Success(Report.find_by!(reporter:, reported:))
    end

    private

    def require_reporter(player)
      player.is_a?(Player) && player.persisted? && !player.banned? ? Success(player) : Failure(:player_required)
    end

    def require_reported(reporter, reported)
      return Failure(:player_not_found) unless reported.is_a?(Player) && reported.persisted?

      reported == reporter ? Failure(:cannot_report_self) : Success(reported)
    end

    def check(reason)
      return Failure(:invalid_reason) unless reason.is_a?(String) || reason.is_a?(Symbol)

      Report.reasons.key?(reason.to_s) ? Success(reason.to_s) : Failure(:invalid_reason)
    end

    def within_limit(reporter)
      Report.where(reporter:, created_at: PERIOD.ago..).count < LIMIT ? Success() : Failure(:rate_limited)
    end
  end
end
