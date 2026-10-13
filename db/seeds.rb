# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Development only: a small published season of generic cards, so packs can
# be opened without running a Steam import. Only while no season is
# published; a run that stopped midway is resumed: the upserts are idempotent
# by source key and fill the existing draft, which is then published. Every
# tenth card has no theme, so the season holds the UFOs beside its themes;
# every seventh and eleventh card belong to a franchise, and four studios
# share the cards, so the season holds franchise and studio sets too; every
# fifteenth card is a little-reviewed 98 % and every twelfth has 250,000
# reviews, so with the ratings' spread each hall of fame set has cards.
# Publishing it fills the banks of the players already there
# (Catalog::SeasonPublished).
if Rails.env.development? && Catalog::PublishedSeason.call.nil?
  card_count = 60

  card_count.times do |index|
    number = index + 1
    hidden_gem = number % 15 == 0
    Catalog::UpsertDraftCard.new.call(
      source_key: "seed:#{number}",
      release_date: Date.new(1990 + (index % 35), 1 + (index % 12), 1),
      image_url: "https://images.example.test/seed-#{number}.jpg",
      store_url: "https://store.example.test/seed-#{number}",
      texts: {
        "en" => { title: "Seed Game #{number}", short_description: "A generic game for development, number #{number}." },
        "fr" => { title: "Jeu témoin #{number}", short_description: "Un jeu générique pour le développement, numéro #{number}." }
      },
      prestige_score: number.to_f,
      prestige_score_version: Steam::PrestigeScore::VERSION,
      rating: hidden_gem ? 98.0 : 50.0 + (index % 50),
      review_count: if hidden_gem then 500 elsif number % 12 == 0 then 250_000 else 1_000 * number end,
      publisher: "Seed Publisher #{(index % 6) + 1}",
      developers: [ "Seed Studio #{(index % 4) + 1} Ltd." ],
      franchises: [ ("Seed Chronicles" if number % 7 == 0), ("Seed Legends Series" if number % 11 == 0) ].compact,
      genres: number % 10 == 0 ? [] : [ %w[fps rpg strategy].fetch(index % 3) ]
    ).value!
  end

  season = Catalog::DraftSeason.call
  Catalog::PublishSeason.new.call(number: season.number).value!
  puts "Seeded and published season #{season.number} with #{card_count} cards."
end
