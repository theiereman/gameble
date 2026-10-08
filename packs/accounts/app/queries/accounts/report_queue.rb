module Accounts
  module ReportQueue
    def self.call(viewer:)
      Report.joins(:reported).merge(Player.in_good_standing)
        .where.not(reported_id: viewer.id)
        .preload(:reporter, :reported)
        .order(created_at: :desc, id: :desc)
        .to_a
    end
  end
end
