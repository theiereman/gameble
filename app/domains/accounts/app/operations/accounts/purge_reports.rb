module Accounts
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
