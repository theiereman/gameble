module Game
  class Pack < ApplicationRecord
    self.table_name = "game_packs"

    SIZE = 5

    BONUS_SIZE = 3

    BANK_SIZE = 10

    INTERVAL = 10.minutes

    REVEAL_MODES = %w[all one_by_one].freeze

    has_secure_token :token

    enum :kind, { regular: "regular", bonus: "bonus", reward: "reward" }, validate: true

    validates :reveal_mode, inclusion: { in: REVEAL_MODES }, allow_nil: true

    scope :unopened, -> { where(opened_at: nil) }
    scope :bank, ->(player_id) { regular.unopened.where(player_id:) }
    scope :available, ->(now = Time.current) { unopened.where(available_at: ..now).order(:available_at, :id) }
    scope :latest_opened, -> { where.not(opened_at: nil).order(opened_at: :desc, id: :desc) }

    def self.row(player_id:, kind:, season_id:, card_season_ids:, available_at:)
      { player_id:, token: generate_unique_secure_token, kind: kind.to_s, season_id:, card_season_ids:, available_at: }
    end

    def opened?
      opened_at.present?
    end

    def card_back_key
      card_back || CardBacks::STANDARD
    end
  end
end
