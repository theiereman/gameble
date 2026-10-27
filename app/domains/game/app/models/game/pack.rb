module Game
  # A pack in a player's bank (CAP-4, AD-7): its cards pre-drawn in order
  # (`card_season_ids`, ids of the season's card-seasons), the time it becomes
  # available and, once opened, the time it was. Bonus and reward packs are
  # rows of the same table. Addressed in URLs by its token (AD-15).
  #
  # Once opened, a pack also keeps the card back the player had on
  # (`card_back`, a Game::CardBacks key; nil for the packs opened before it
  # was kept) and, when the booster's JSON exchange opened it, the request's
  # Idempotency-Key (`idempotency_key`, a UUID unique per player, AD-23), so
  # the same request replays the same pack.
  #
  # No association to Catalog: the database keys suffice, and the catalog is
  # read through its queries. Written only through the operations of this
  # pack (AD-3).
  class Pack < ApplicationRecord
    self.table_name = "game_packs"

    # Cards in a regular pack.
    SIZE = 5

    # Cards in a daily bonus pack (CAP-16), drawn with DrawOdds::BONUS.
    BONUS_SIZE = 3

    # Unopened regular packs a player's bank holds (CAP-4, AD-7): bonus and
    # reward packs are outside it.
    BANK_SIZE = 10

    # Time between two packs of the bank's schedule.
    INTERVAL = 10.minutes

    has_secure_token :token

    enum :kind, { regular: "regular", bonus: "bonus", reward: "reward" }, validate: true

    scope :unopened, -> { where(opened_at: nil) }
    # The bank: the player's unopened regular packs, available or scheduled.
    scope :bank, ->(player_id) { regular.unopened.where(player_id:) }
    # Unopened and available at `now`, the next one to open first.
    scope :available, ->(now = Time.current) { unopened.where(available_at: ..now).order(:available_at, :id) }

    # The attributes of a new pack, with a fresh token: the one shape of the
    # rows that Game::FillBank and Game::TopUpBank insert (insert_all!) and
    # Game::CollectDailyBonus creates.
    def self.row(player_id:, kind:, season_id:, card_season_ids:, available_at:)
      { player_id:, token: generate_unique_secure_token, kind: kind.to_s, season_id:, card_season_ids:, available_at: }
    end

    def opened?
      opened_at.present?
    end

    # The key of the card back the pack was opened with: `standard` for a
    # pack opened before the back was kept.
    def card_back_key
      card_back || CardBacks::STANDARD
    end
  end
end
