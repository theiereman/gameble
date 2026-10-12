module Catalog
  # Fills, once, what a source gives a card that the imports written before
  # did not store: each card's developers, franchises and genres (theme
  # keys, as Catalog::UpsertDraftCard takes them), and the review count of
  # its card-seasons that have none. Published card-seasons are filled too,
  # the one exception to their frozen season data: their count was never
  # set, so no published value changes; their main theme is never touched.
  #
  # Rows are keyed by the card's source key; a row whose card does not exist
  # is ignored, and a row with a nil review count fills no card-season. All
  # rows are written in one transaction, in two bulk UPDATEs, the rows
  # travelling as one jsonb document. Idempotent: a card already holding the
  # names and genres and a card-season already holding a count are left as
  # they are, so a second call fills nothing.
  #
  # Publishes Catalog::CardSourcesFilled with the counts, even when nothing
  # was filled.
  #
  #   Catalog::FillCardSources.new.call(rows: [
  #     { source_key: "steam:620", developers: [ "Valve" ], franchises: [ "Portal" ], genres: [ "puzzle" ], review_count: 1_000 }
  #   ])
  #   # => Success({ cards: 1, card_seasons: 2 }) | Failure(:invalid_card)
  class FillCardSources < ApplicationOperation
    STREAM = "Catalog::CardSources".freeze
    ROW_KEYS = %i[source_key developers franchises genres review_count].freeze
    SOURCES = "jsonb_to_recordset(?::jsonb) AS sources(source_key varchar, developers varchar[], franchises varchar[], " \
      "genres varchar[], review_count integer)".freeze

    def call(rows:)
      rows = step validate_rows(rows)

      transaction do
        now = Time.current
        filled = { cards: fill_cards(rows, now), card_seasons: fill_card_seasons(rows, now) }
        step publish(CardSourcesFilled.new(data: filled), stream_name: STREAM)
        filled
      end
    end

    private

    # The rows as given, one per source key (the last one wins).
    def validate_rows(rows)
      return Failure(:invalid_card) unless rows.is_a?(Array) && rows.all? { |row| valid_row?(row) }

      Success(rows.map { |row| row.slice(*ROW_KEYS) }.index_by { |row| row[:source_key] }.values)
    end

    def valid_row?(row)
      row.is_a?(Hash) && row.keys.to_set == ROW_KEYS.to_set &&
        present_string?(row[:source_key]) &&
        row.values_at(:developers, :franchises).all? { |list| list.is_a?(Array) && list.all? { |name| present_string?(name) } } &&
        row[:genres].is_a?(Array) && row[:genres].all? { |genre| Themes.key?(genre) } &&
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
