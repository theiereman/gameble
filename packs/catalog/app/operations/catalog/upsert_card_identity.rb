module Catalog
  # Writes a card's identity (texts, publisher, developers, franchises,
  # release date, store and image URL), whatever its source: the card is
  # keyed by an opaque source key the caller builds. Idempotent: the
  # same source key again updates the card and its texts in place, even when
  # the card is in a published season. Touches no season: the card's season
  # scores are staged apart (Catalog::StageCardSeason).
  #
  # `genres` are theme keys (Catalog::Themes), most-voted first; a genre
  # outside the list is refused.
  #
  # Publishes Catalog::CardIdentityUpserted on every call.
  #
  #   Catalog::UpsertCardIdentity.new.call(
  #     source_key: "src:620", release_date: Date.new(2011, 4, 18),
  #     image_url: "https://…", store_url: "https://…",
  #     texts: { "en" => { title: "Portal 2", short_description: "…" }, "fr" => { title: "Portal 2" } },
  #     publisher: "…", genres: %w[puzzle], tags: %w[puzzle], developers: %w[Valve], franchises: [ "Portal" ]
  #   )
  #   # => Success(card) | Failure(:missing_text) | Failure(:invalid_card)
  class UpsertCardIdentity < ApplicationOperation
    include CardWriting

    def call(source_key:, release_date:, image_url:, store_url:, texts:, publisher: nil, genres: [], tags: [], developers: [],
             franchises: [])
      card_attributes = step validate_card(source_key:, release_date:, image_url:, store_url:, publisher:, genres:, tags:,
        developers:, franchises:)
      texts = step validate_texts(texts)

      transaction do
        card = step upsert_card(card_attributes, texts)
        step publish(CardIdentityUpserted.new(data: { card_id: card.id }), stream_name: "Catalog::Card$#{card.id}")
        card
      end
    end
  end
end
