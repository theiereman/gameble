module Accounts
  module Feedbacks
    def self.by_feature
      Feedback.includes(:player).newest_first.group_by(&:feature)
    end
  end
end
