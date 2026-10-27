module Game
  class Pack < ApplicationRecord
    self.table_name = "game_packs"

    SIZE = 5

    BONUS_SIZE = 3

    BANK_SIZE = 10

    INTERVAL = 10.minutes

    has_secure_token :token

    enum :kind, { regular: "regular", bonus: "bonus", reward: "reward" }, validate: true

    scope :unopened, -> { where(opened_at: nil) }
    scope :bank, ->(player_id) { regular.unopened.where(player_id:) }
    scope :available, ->(now = Time.current) { unopened.where(available_at: ..now).order(:available_at, :id) }

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
