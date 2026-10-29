module Accounts
  class Player < ApplicationRecord
    self.table_name = "accounts_players"

    STEAM_ID_FORMAT = /\A\d{17}\z/

    IDLE_PERIOD = 3.years

    EXPORT_INTERVAL = 5.minutes

    has_secure_token :token

    def next_export_at(now = Time.current)
      next_at = last_exported_at && last_exported_at + EXPORT_INTERVAL
      next_at if next_at && next_at > now
    end

    before_save :rotate_stream_key, if: :banned_or_deleted_now?

    RANKS = %w[player moderator administrator].freeze

    enum :role, RANKS.index_by(&:to_sym), default: :player, validate: true

    enum :visibility, { public: "public", friends_only: "friends_only", private: "private" },
      default: :public, prefix: :visibility, validate: true

    has_many :identities, class_name: "Accounts::Identity", foreign_key: :player_id, inverse_of: :player

    validates :steam_id, format: { with: STEAM_ID_FORMAT }, allow_nil: true

    scope :in_good_standing, -> { where(banned_at: nil, deleted_at: nil) }
    scope :removed, -> { where.not(banned_at: nil).or(where.not(deleted_at: nil)) }
    scope :idle, ->(now) {
      where(role: :player).in_good_standing.where("GREATEST(last_seen_at, updated_at) < ?", now - IDLE_PERIOD)
    }

    def self.acting_staff?(player)
      player.is_a?(Player) && player.persisted? && player.staff? && !player.removed?
    end

    def banned?
      banned_at.present?
    end

    def deleted?
      deleted_at.present?
    end

    def removed?
      banned? || deleted?
    end

    def staff?
      moderator? || administrator?
    end

    def outranks?(other)
      RANKS.index(role) > RANKS.index(other.role)
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
