module Accounts
  # A player (CAP-1). Known by a Steam id; addressed in public by a random
  # token, never by its database id (AD-15). No name, avatar or password.
  class Player < ApplicationRecord
    self.table_name = "accounts_players"

    STEAM_ID_FORMAT = /\A\d{17}\z/

    has_secure_token :token

    # Uniqueness of the Steam id is the unique index's job: a validation would
    # race, and Accounts::SignIn relies on the index conflict.
    validates :steam_id, presence: true, format: { with: STEAM_ID_FORMAT }
  end
end
