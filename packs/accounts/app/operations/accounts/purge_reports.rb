module Accounts
  # Erases up to `limit` reports kept past their retention: handled more than
  # RETENTION ago, or against an account deleted more than RETENTION ago
  # (such a report is never handled). Housekeeping: no event names the rows
  # it erases.
  #
  #   Accounts::PurgeReports.new.call(now: Time.current, limit: 1000) # => Success(count)
  class PurgeReports < ApplicationOperation
    RETENTION = 1.year

    def call(now:, limit:)
      transaction do
        Report.where(id: expired(now - RETENTION).limit(limit).select(:id)).delete_all
      end
    end

    private

    def expired(cutoff)
      Report.joins(:reported)
        .where("accounts_reports.handled_at < :cutoff OR accounts_players.deleted_at < :cutoff", cutoff:)
    end
  end
end
