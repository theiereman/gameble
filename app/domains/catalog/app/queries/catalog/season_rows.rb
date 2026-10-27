module Catalog
  module SeasonRows
    Row = Data.define(:id, :card_id, :prestige_score, :prestige_score_version, :rating, :release_date, :genres,
      :title, :developers, :franchises, :publisher, :review_count, :tags)

    ENGLISH_TEXT = <<~SQL.squish.freeze
      LEFT JOIN catalog_card_texts ON catalog_card_texts.card_id = catalog_cards.id AND catalog_card_texts.locale = 'en'
    SQL

    COLUMNS = [
      :id, :card_id, :prestige_score, :prestige_score_version, :rating,
      "catalog_cards.release_date", "catalog_cards.genres", "catalog_card_texts.title", "catalog_cards.developers",
      "catalog_cards.franchises", "catalog_cards.publisher", :review_count, "catalog_cards.tags"
    ].freeze

    def self.call(season_id)
      of(CardSeason.where(season_id:))
    end

    def self.staged(batch_token)
      of(StagedCardSeason.where(batch_token:))
    end

    def self.of(card_seasons)
      card_seasons.joins(:card).joins(ENGLISH_TEXT).order(:id).pluck(*COLUMNS)
        .map do |id, card_id, prestige_score, prestige_score_version, rating, release_date, genres, title, developers, franchises, publisher, review_count, tags|
          Row.new(id:, card_id:, prestige_score:, prestige_score_version:, rating:, release_date:, genres:,
            title:, developers:, franchises:, publisher:, review_count:, tags:)
        end
    end
    private_class_method :of
  end
end
