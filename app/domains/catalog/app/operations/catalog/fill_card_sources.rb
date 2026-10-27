module Catalog
  class FillCardSources < ApplicationOperation
    STREAM = "Catalog::CardSources".freeze
    ROW_KEYS = %i[source_key developers franchises genres review_count].freeze
    SOURCES = "jsonb_to_recordset(?::jsonb) AS sources(source_key varchar, developers varchar[], franchises varchar[], " \
      "genres varchar[], review_count integer)".freeze

    def call(rows:)
      rows = step validate_rows(rows, Themes.keys.to_set)

      transaction do
        now = Time.current
        filled = { cards: fill_cards(rows, now), card_seasons: fill_card_seasons(rows, now) }
        step publish(CardSourcesFilled.new(data: filled), stream_name: STREAM)
        filled
      end
    end

    private

    def validate_rows(rows, theme_keys)
      return Failure(:invalid_card) unless rows.is_a?(Array) && rows.all? { |row| valid_row?(row, theme_keys) }

      Success(rows.map { |row| row.slice(*ROW_KEYS) }.index_by { |row| row[:source_key] }.values)
    end

    def valid_row?(row, theme_keys)
      row.is_a?(Hash) && row.keys.to_set == ROW_KEYS.to_set &&
        present_string?(row[:source_key]) &&
        row.values_at(:developers, :franchises).all? { |list| list.is_a?(Array) && list.all? { |name| present_string?(name) } } &&
        row[:genres].is_a?(Array) && row[:genres].all? { |genre| theme_keys.include?(genre) } &&
        (row[:review_count].nil? || (row[:review_count].is_a?(Integer) && CardSeason::REVIEW_COUNTS.cover?(row[:review_count])))
    end

    def present_string?(value)
      value.is_a?(String) && value.present?
    end

    def fill_cards(rows, now)
      Card.joins(sources_join(rows))
        .where("catalog_cards.developers IS DISTINCT FROM sources.developers OR catalog_cards.franchises IS DISTINCT FROM sources.franchises " \
          "OR catalog_cards.genres IS DISTINCT FROM sources.genres")
        .update_all([ "developers = sources.developers, franchises = sources.franchises, genres = sources.genres, updated_at = ?", now ])
    end

    def fill_card_seasons(rows, now)
      CardSeason.joins(:card).joins(sources_join(rows))
        .where(review_count: nil).where.not(sources: { review_count: nil })
        .update_all([ "review_count = sources.review_count, updated_at = ?", now ])
    end

    def sources_join(rows)
      Card.sanitize_sql_array([ "JOIN #{SOURCES} ON sources.source_key = catalog_cards.source_key", rows.to_json ])
    end
  end
end
