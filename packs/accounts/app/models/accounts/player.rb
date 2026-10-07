module Accounts
  # A player (CAP-1). Known by a Steam id; addressed in public by a random
  # token, never by its database id (AD-15). The token is a public,
  # non-secret handle: it is the link to the player's public profile (CAP-8).
  # No avatar or password.
  #
  # Its display name is the Steam persona name read at the last sign-in
  # (`persona_name`, nil until Steam gives one): a label, not unique, which
  # titles the public profile. Reports and moderation key on the token. It is
  # personal data: an account's export and deletion include it.
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

    # Who may see the player's profile (CAP-14): everyone, their friends only
    # (counted by Game::Visibility, nobody until epic 5) or only them. The
    # prefix keeps `private` from clashing with Ruby's own.
    enum :visibility, { public: "public", friends_only: "friends_only", private: "private" },
      default: :public, prefix: :visibility, validate: true

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
