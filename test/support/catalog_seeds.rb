# Seeds card-seasons straight into the database with insert_all (slugs set),
# for tests that need many cards without going through the card operations.
module CatalogSeeds
  # A draft season (the next number) unless one is given, with one card and
  # card-season per score, and an `en` and `fr` title per card.
  # Per card, in the order of the scores: `titles` defaults to "Seed <i>",
  # `release_dates` to 2000-01-01, `publishers` to nil, `genres` to ["rpg"] (no UFO, whose share a publication limits),
  # `developers` and `franchises` to [], `ratings` to 80.0, `review_counts`
  # to 5,000 (no hall of fame or studio set) and `score_versions` (the
  # prestige score's version) to nil. `tags` defaults to the first tag of
  # each genre's theme (the genre itself when it is no theme), so the draft
  # holds what a rescore would give.
  # Returns the season.
  def seed_card_seasons(scores, season: nil, release_dates: nil, publishers: nil, genres: nil, ratings: nil, score_versions: nil,
                        titles: nil, developers: nil, franchises: nil, review_counts: nil, prefix: "seed", tags: nil)
    season ||= Catalog::Season.create!(status: :draft, number: Catalog::Season.next_number)
    return season if scores.empty?

    release_dates ||= Array.new(scores.size, Date.new(2000, 1, 1))
    publishers ||= Array.new(scores.size)
    genres ||= Array.new(scores.size) { [ "rpg" ] }
    ratings ||= Array.new(scores.size, 80.0)
    score_versions ||= Array.new(scores.size)
    titles ||= Array.new(scores.size) { |index| "Seed #{index}" }
    developers ||= Array.new(scores.size) { [] }
    franchises ||= Array.new(scores.size) { [] }
    review_counts ||= Array.new(scores.size, 5_000)
    tags ||= genres.map { |card_genres| card_genres.map { |genre| tag_of_theme(genre) } }

    cards = scores.each_index.map do |index|
      key = "#{prefix}-#{season.number}-#{index}"
      { source_key: "test:#{key}", slug: key, release_date: release_dates.fetch(index), publisher: publishers.fetch(index),
        genres: genres.fetch(index), tags: tags.fetch(index), developers: developers.fetch(index), franchises: franchises.fetch(index),
        image_url: "https://images.example.test/#{key}.jpg", store_url: "https://store.example.test/#{key}" }
    end
    ids = Catalog::Card.insert_all!(cards, returning: :id).rows.flatten
    Catalog::CardText.insert_all!(ids.each_with_index.flat_map do |card_id, index|
      %w[en fr].map { |locale| { card_id:, locale:, title: titles.fetch(index) } }
    end)
    Catalog::CardSeason.insert_all!(ids.each_with_index.map do |card_id, index|
      { card_id:, season_id: season.id, prestige_score: scores.fetch(index), prestige_score_version: score_versions.fetch(index),
        rating: ratings.fetch(index), review_count: review_counts.fetch(index) }
    end)
    season
  end

  # The sets acceptance draft, 150 distinct scores: publisher P with 5 cards and Q with 4; genres [roguelike] x 75
  # (the even cards), [rpg, roguelike] x 44 (odd, below 88), [horror, pirates] x 8 (odd, 89 to 103), [horror] x 8
  # (odd, 105 to 119), roguelike x 8 (odd, 121 to 135), none x 7 (the UFOs, 4.7 %); released in 2011 x 12, 2012 x 9, 2015 x 129. Published, it holds the
  # theme sets roguelike (127 cards), rpg (44), horror (16) and pirates (8), and the UFOs (7).
  def seed_sets_draft
    release_dates = Array.new(12) { |i| Date.new(2011, 1 + i, 1) } + Array.new(9) { |i| Date.new(2012, 1 + i, 1) } +
      Array.new(129) { |i| Date.new(2015, 1, 1) + i }
    publishers = Array.new(150) { |i| if i.between?(140, 144) then "P" elsif i.between?(145, 148) then "Q" end }
    genres = Array.new(150) do |i|
      if i.even? then [ "roguelike" ]
      elsif i < 88 then [ "rpg", "roguelike" ]
      elsif i < 104 then [ "horror", "pirates" ]
      elsif i < 120 then [ "horror" ]
      elsif i < 136 then [ "roguelike" ]
      else []
      end
    end
    ratings = Array.new(150) { |i| 50 + (i * 37 % 50) }
    seed_card_seasons(distinct_scores(150), release_dates:, publishers:, genres:, ratings:)
  end

  # The sets acceptance draft, published (the newest published season): its
  # sets are built by Catalog::PublishSeason. Returns the season.
  def publish_sets_draft
    season = seed_sets_draft
    assert Catalog::PublishSeason.new.call(number: season.number).success?
    season.reload
  end

  # A draft of 24 distinct scores, every card an RPG but the last (the
  # UFO), released a month apart in card order: cards 0 to 2 of the
  # franchise "Tom Clancy Franchise", titled "Tom Clancy's …"; cards 3 to 5
  # developed by "CAPCOM Co., Ltd." twice then "Capcom", the first with
  # 25,000 reviews; cards 6 to 8 of the franchise "Team17", developed by
  # "Team17", titled "Team17 …", none reviewed. Published, it holds the
  # theme rpg (23 cards), the franchise tom-clancy ("Tom Clancy", 3 cards),
  # the studio capcom ("CAPCOM", 3 cards) and the UFOs (1): Team17 is
  # named like a studio, and too little reviewed to be one.
  def seed_franchises_and_studios_draft
    count = 24
    titles = Array.new(count) { |index| "Seed #{index}" }
    titles[0, 3] = [ "Tom Clancy's Rainbow Six", "Tom Clancy's The Division", "Tom Clancy's Ghost Recon" ]
    titles[6, 3] = [ "Team17 Worms", "Team17 Overcooked", "Team17 Golf" ]
    franchises = Array.new(count) { |index| if index < 3 then [ "Tom Clancy Franchise" ] elsif index.between?(6, 8) then [ "Team17" ] else [] end }
    developers = Array.new(count) { [] }
    developers[3, 3] = [ [ "CAPCOM Co., Ltd." ], [ "CAPCOM Co., Ltd." ], [ "Capcom" ] ]
    developers[6, 3] = Array.new(3) { [ "Team17" ] }
    review_counts = Array.new(count, 5_000)
    review_counts[3] = 25_000
    seed_card_seasons(distinct_scores(count), titles:, franchises:, developers:, review_counts:,
      release_dates: Array.new(count) { |index| Date.new(2000, 1, 1) >> index },
      genres: Array.new(count) { |index| index < count - 1 ? [ "rpg" ] : [] })
  end

  # The franchises and studios draft, published. Returns the season.
  def publish_franchises_and_studios_draft
    season = seed_franchises_and_studios_draft
    assert Catalog::PublishSeason.new.call(number: season.number).success?
    season.reload
  end

  # A draft of 24 distinct scores, every card an RPG, released a month apart
  # in card order, the first eight at a rating and review count: 0 at 97 %
  # and 20,000 reviews, 1 at 98 % and 999, 2 at 69 % and 20,000, 3 at 40 %
  # and 20,000, 4 at 85 % and 200,000, 5 at 98 % and 250,000, 6 at 96 % and
  # 50,000, 7 at 99 % and 1,000; the others at 80 % and 5,000. Published,
  # it holds the theme rpg (24 cards) and the hall of fame sets intouchables
  # (cards 0 and 5), pepites (1), mal-aimes (2 and 3) and phenomenes (4 and
  # 5).
  def seed_hall_of_fame_draft
    count = 24
    seed_card_seasons(distinct_scores(count), genres: Array.new(count) { [ "rpg" ] },
      ratings: [ 97, 98, 69, 40, 85, 98, 96, 99 ] + Array.new(count - 8, 80),
      review_counts: [ 20_000, 999, 20_000, 20_000, 200_000, 250_000, 50_000, 1_000 ] + Array.new(count - 8, 5_000),
      release_dates: Array.new(count) { |index| Date.new(2000, 1, 1) >> index })
  end

  # The hall of fame draft, published. Returns the season.
  def publish_hall_of_fame_draft
    season = seed_hall_of_fame_draft
    assert Catalog::PublishSeason.new.call(number: season.number).success?
    season.reload
  end

  # A new published season (the next number) holding exactly these sets,
  # without members: `sets` is [ [ kind, key, params ], … ]. Written with
  # insert_all, as a published season's sets can no longer be created.
  # Returns the season.
  def seed_published_sets(sets)
    season = Catalog::Season.create!(status: :draft, number: Catalog::Season.next_number)
    season.update!(status: :published, published_at: Time.current)
    Catalog::Set.insert_all!(sets.map { |kind, key, params| { season_id: season.id, kind:, key:, params: } }) if sets.any?
    season
  end

  # The first tag attached to the theme `genre`, or `genre` itself.
  def tag_of_theme(genre)
    @tag_of_theme ||= Catalog::TagClassification.joins(:theme).order(:id).pluck("catalog_themes.key", :tag_key).reverse.to_h
    @tag_of_theme.fetch(genre, genre)
  end

  # `count` distinct scores, the highest first: count, count - 1, … 1.
  def distinct_scores(count)
    Array.new(count) { |index| (count - index).to_f }
  end
end
