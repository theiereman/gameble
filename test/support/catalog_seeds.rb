# Seeds card-seasons straight into the database with insert_all (slugs set),
# for tests that need many cards without going through UpsertDraftCard.
module CatalogSeeds
  # A draft season (the next number) unless one is given, with one card and
  # card-season per score. `release_dates` defaults to 2000-01-01 for every
  # card. Returns the season.
  def seed_card_seasons(scores, season: nil, release_dates: nil, prefix: "seed")
    season ||= Catalog::Season.create!(status: :draft, number: Catalog::Season.next_number)
    release_dates ||= Array.new(scores.size, Date.new(2000, 1, 1))
    return season if scores.empty?

    cards = scores.each_index.map do |index|
      key = "#{prefix}-#{season.number}-#{index}"
      { source_key: "test:#{key}", slug: key, release_date: release_dates.fetch(index),
        image_url: "https://images.example.test/#{key}.jpg", store_url: "https://store.example.test/#{key}" }
    end
    ids = Catalog::Card.insert_all!(cards, returning: :id).rows.flatten
    Catalog::CardSeason.insert_all!(ids.zip(scores).map do |card_id, score|
      { card_id:, season_id: season.id, prestige_score: score, rating: 80.0 }
    end)
    season
  end

  # `count` distinct scores, the highest first: count, count - 1, … 1.
  def distinct_scores(count)
    Array.new(count) { |index| (count - index).to_f }
  end
end
