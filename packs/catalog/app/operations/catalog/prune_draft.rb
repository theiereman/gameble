module Catalog
  # Keeps only the given cards in the draft season (CAP-2, AD-5): every
  # draft card-season whose card's source key is not in `keep_source_keys`
  # is removed, in bulk. The keys are opaque (AD-4): the source builds them,
  # and calls this at the end of a pass so the draft holds exactly that
  # pass's cards.
  #
  # Only the draft is touched: a published season's card-seasons and sets
  # never are (a draft has no sets yet), and the cards and their texts stay
  # (their identity and slugs). The draft is locked FOR SHARE, like
  # UpsertDraftCard, so a publication waits for the prune. The keys travel as
  # one Postgres array literal, never one bind each: a pass keeps tens of
  # thousands of cards.
  #
  # With no draft, nothing is removed and no event is published. Otherwise
  # Catalog::DraftPruned is published, even when nothing was removed.
  #
  #   Catalog::PruneDraft.new.call(keep_source_keys: [ "steam:620", "steam:400" ])
  #   # => Success(3), the card-seasons removed
  class PruneDraft < ApplicationOperation
    ARRAY = PG::TextEncoder::Array.new

    def call(keep_source_keys:)
      keys = Array(keep_source_keys).map(&:to_s)

      transaction do
        season = find_draft_season
        if season
          removed = step remove_others(season, keys)
          step publish(DraftPruned.new(data: { season_id: season.id, removed: removed }), stream_name: Season.stream_name(season.id))
          removed
        else
          0
        end
      end
    end

    private

    def find_draft_season
      Season.draft.lock("FOR SHARE").take
    end

    def remove_others(season, keys)
      kept_cards = Card.where("source_key = ANY(?::text[])", ARRAY.encode(keys)).select(:id)
      Success(CardSeason.where(season_id: season.id).where.not(card_id: kept_cards).delete_all)
    end
  end
end
