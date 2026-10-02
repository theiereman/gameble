module Accounts
  # A player (CAP-1). Known by a Steam id; addressed in public by a random
  # token, never by its database id (AD-15). No name, avatar or password.
  #
  # A player holds one role (AD-14): player, moderator or administrator; a
  # signed-out visitor is the absence of a player. A ban is the time it took
  # effect; a banned player cannot sign in and is signed out on their next
  # request.
  class Player < ApplicationRecord
    self.table_name = "accounts_players"

    STEAM_ID_FORMAT = /\A\d{17}\z/

    has_secure_token :token

    enum :role, { player: "player", moderator: "moderator", administrator: "administrator" },
      default: :player, validate: true

    # Uniqueness of the Steam id is the unique index's job: a validation would
    # race, and Accounts::SignIn relies on the index conflict.
    validates :steam_id, presence: true, format: { with: STEAM_ID_FORMAT }

    def banned?
      banned_at.present?
    end

    # A moderator or an administrator.
    def staff?
      moderator? || administrator?
    end
  end
end
