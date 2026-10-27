module Game
  class Invitation < ApplicationRecord
    self.table_name = "game_invitations"

    STATUSES = %w[pending accepted ignored].freeze

    has_secure_token :token, length: 24

    scope :pending, -> { where(status: "pending") }
    scope :unanswered, -> { where(status: %w[pending ignored]) }
    scope :between, ->(one_id, other_id) { where(sender_id: [ one_id, other_id ], recipient_id: [ one_id, other_id ]) }
  end
end
