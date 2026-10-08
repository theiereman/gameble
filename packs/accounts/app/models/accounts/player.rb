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
  #
  # A deleted account (Accounts::DeletePlayer) keeps its record, as the
  # target of the rows that name it, anonymised: no Steam id (released, so
  # the player can sign up again), no name, a new token, and `deleted_at`.
  class Player < ApplicationRecord
    self.table_name = "accounts_players"

    STEAM_ID_FORMAT = /\A\d{17}\z/

    has_secure_token :token

    before_save :rotate_stream_key, if: :banned_or_deleted_now?

    enum :role, { player: "player", moderator: "moderator", administrator: "administrator" },
      default: :player, validate: true

    # Who may see the player's profile (CAP-14): everyone, their friends only
    # (decided by Game::Visibility, the friendships being Game's) or only
    # them. The prefix keeps `private` from clashing with Ruby's own.
    enum :visibility, { public: "public", friends_only: "friends_only", private: "private" },
      default: :public, prefix: :visibility, validate: true

    # Uniqueness of the Steam id is the unique index's job: a validation would
    # race, and Accounts::SignIn relies on the index conflict.
    validates :steam_id, presence: true, format: { with: STEAM_ID_FORMAT }, unless: :deleted?

    scope :in_good_standing, -> { where(banned_at: nil, deleted_at: nil) }
    scope :removed, -> { where.not(banned_at: nil).or(where.not(deleted_at: nil)) }

    def banned?
      banned_at.present?
    end

    def deleted?
      deleted_at.present?
    end

    def removed?
      banned? || deleted?
    end

    # A moderator or an administrator.
    def staff?
      moderator? || administrator?
    end

    private

    def banned_or_deleted_now?
      (will_save_change_to_banned_at? && banned_at.present?) || (will_save_change_to_deleted_at? && deleted_at.present?)
    end

    def rotate_stream_key
      self.stream_key = SecureRandom.uuid
    end
  end
end
