module Catalog
  class UpsertCardIdentity < ApplicationOperation
    include CardWriting

    def call(source_key:, release_date:, image_url:, store_url:, texts:, publisher: nil, genres: [], tags: [], developers: [],
             franchises: [], theme_keys: nil)
      card_attributes = step validate_card(source_key:, release_date:, image_url:, store_url:, publisher:, genres:, tags:,
        developers:, franchises:, theme_keys:)
      texts = step validate_texts(texts)

      transaction do
        card = step upsert_card(card_attributes, texts)
        step publish(CardIdentityUpserted.new(data: { card_id: card.id }), stream_name: "Catalog::Card$#{card.id}")
        card
      end
    end
  end
end
