module Game
  class Invitation < ApplicationRecord
    self.table_name = "game_invitations"

    STATUSES = %w[pending accepted ignored].freeze

    has_secure_token :token, length: 24

    scope :pending, -> { where(status: "pending") }
  end
end
