module Game
  # A friend invitation (AD-8): from a sender to a recipient, by the
  # recipient's friend code or by the sender opening the recipient's invite
  # link. Pending until the recipient accepts (the friendship is created in
  # the same operation) or ignores. Addressed by its token (AD-15). Written
  # only through the operations of this pack (AD-3).
  class Invitation < ApplicationRecord
    self.table_name = "game_invitations"

    STATUSES = %w[pending accepted ignored].freeze

    has_secure_token :token, length: 24

    scope :pending, -> { where(status: "pending") }
  end
end
