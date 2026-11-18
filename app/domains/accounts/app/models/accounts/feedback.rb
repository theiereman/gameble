module Accounts
  class Feedback < ApplicationRecord
    self.table_name = "accounts_feedbacks"

    # The features staff asked players to test; add one here to open it to feedback.
    FEATURES = %w[duels].freeze
    MESSAGE_LENGTH = 1000

    has_secure_token :token, length: 24

    belongs_to :player, class_name: "Accounts::Player"

    scope :newest_first, -> { order(created_at: :desc, id: :desc) }

    def self.clean(message)
      message.to_s.gsub("\r\n", "\n").strip
    end

    def self.valid_message?(message)
      message.length.between?(1, MESSAGE_LENGTH)
    end
  end
end
