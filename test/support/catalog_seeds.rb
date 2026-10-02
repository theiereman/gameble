# Seeds card-seasons straight into the database with insert_all (slugs set),
# for tests that need many cards without going through UpsertDraftCard.
module CatalogSeeds
  # A draft season (the next number) unless one is given, with one card and
  # card-season per score, and an `en` and `fr` title per card ("Seed <i>").
  # Per card, in the order of the scores: `release_dates` defaults to
  # 2000-01-01, `publishers` to nil, `genres` to [] and `ratings` to 80.0.
  # Returns the season.
  def seed_card_seasons(scores, season: nil, release_dates: nil, publishers: nil, genres: nil, ratings: nil, prefix: "seed")
    season ||= Catalog::Season.create!(status: :draft, number: Catalog::Season.next_number)
    return season if scores.empty?

    release_dates ||= Array.new(scores.size, Date.new(2000, 1, 1))
    publishers ||= Array.new(scores.size)
    genres ||= Array.new(scores.size) { [] }
    ratings ||= Array.new(scores.size, 80.0)

    cards = scores.each_index.map do |index|
      key = "#{prefix}-#{season.number}-#{index}"
      { source_key: "test:#{key}", slug: key, release_date: release_dates.fetch(index), publisher: publishers.fetch(index),
        genres: genres.fetch(index), image_url: "https://images.example.test/#{key}.jpg", store_url: "https://store.example.test/#{key}" }
    end
    ids = Catalog::Card.insert_all!(cards, returning: :id).rows.flatten
    Catalog::CardText.insert_all!(ids.each_with_index.flat_map do |card_id, index|
      %w[en fr].map { |locale| { card_id:, locale:, title: "Seed #{index}" } }
    end)
    Catalog::CardSeason.insert_all!(ids.each_with_index.map do |card_id, index|
      { card_id:, season_id: season.id, prestige_score: scores.fetch(index), rating: ratings.fetch(index) }
    end)
    season
  end

  # The sets acceptance draft (story 2.7), 150 distinct scores: publisher P with 5 cards and Q with 4; genre action
  # 75, rpg 44, none 31; released in 2011 x 12, 2012 x 9, 2015 x 129.
  def seed_sets_draft
    release_dates = Array.new(12) { |i| Date.new(2011, 1 + i, 1) } + Array.new(9) { |i| Date.new(2012, 1 + i, 1) } +
      Array.new(129) { |i| Date.new(2015, 1, 1) + i }
    publishers = Array.new(150) { |i| if i.between?(140, 144) then "P" elsif i.between?(145, 148) then "Q" end }
    genres = Array.new(150) { |i| if i.even? then [ "action" ] elsif i < 88 then [ "rpg", "action" ] else [] end }
    ratings = Array.new(150) { |i| 50 + (i * 37 % 50) }
    seed_card_seasons(distinct_scores(150), release_dates:, publishers:, genres:, ratings:)
  end

  # `count` distinct scores, the highest first: count, count - 1, … 1.
  def distinct_scores(count)
    Array.new(count) { |index| (count - index).to_f }
  end
end
