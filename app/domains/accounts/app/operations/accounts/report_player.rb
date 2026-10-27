module Accounts
  class ReportPlayer < ApplicationOperation
    LIMIT = 5
    PERIOD = 1.day

    def call(reporter:, reported:, reason:)
      reporter = step require_reporter(reporter)
      reported = step require_reported(reporter, reported)
      reason = step check(reason)

      transaction do
        # Serializes one reporter's reports so the daily limit cannot be raced.
        reporter.lock!
        existing = Report.find_by(reporter:, reported:)
        next existing if existing

        step within_limit(reporter)
        Report.create!(reporter:, reported:, reason:)
      end
    rescue ActiveRecord::RecordNotUnique
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
