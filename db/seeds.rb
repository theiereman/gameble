# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# The themes and the classification of their tags a fresh database starts
# with, in every environment; once a theme exists, the administrators own
# the list and this leaves it alone.
if Catalog::Theme.none?
  YAML.load_file(Rails.root.join("db/default_themes.yml")).each do |key, default|
    theme = Catalog::Theme.create!(key:, name_en: default["en"], name_fr: default["fr"])
    Catalog::TagClassification.insert_all!(default["tags"].map { |tag_key| { tag_key:, theme_id: theme.id, not_a_theme: false } })
  end
  Catalog::TagClassification.insert_all!(YAML.load_file(Rails.root.join("db/default_dismissed_tags.yml")).map do |tag_key|
    { tag_key:, theme_id: nil, not_a_theme: true }
  end)
end

# The market's first settings version, closed, with the starting values; once any version exists this leaves it alone.
Game::Market::CreateFirstSettings.new.call.value!

# Development only: a small published season of generic cards, so packs can
# be opened without running a Steam import. Only while no season is
# published; a run that stopped midway is resumed: the identity upserts and
# the staging are idempotent, and the promotion refills the draft, which is
# then published. Every
# tenth card has no theme, so the season holds the UFOs beside its themes;
# every seventh and eleventh card belong to a franchise, and four studios
# share the cards, so the season holds franchise and studio sets too; every
# fifteenth card is a little-reviewed 98 % and every twelfth has 250,000
# reviews, so with the ratings' spread each hall of fame set has cards.
# Publishing it fills the banks of the players already there
# (Catalog::SeasonPublished).
if Rails.env.development? && Catalog::PublishedSeason.call.nil?
  card_count = 60
  seed_batch = "development-seed"

  card_count.times do |index|
    number = index + 1
    hidden_gem = number % 15 == 0
    card = Catalog::UpsertCardIdentity.new.call(
      source_key: "seed:#{number}",
      release_date: Date.new(1990 + (index % 35), 1 + (index % 12), 1),
      image_url: "https://images.example.test/seed-#{number}.jpg",
      store_url: "https://store.example.test/seed-#{number}",
      texts: {
        "en" => { title: "Seed Game #{number}", short_description: "A generic game for development, number #{number}." },
        "fr" => { title: "Jeu témoin #{number}", short_description: "Un jeu générique pour le développement, numéro #{number}." }
      },
      publisher: "Seed Publisher #{(index % 6) + 1}",
      developers: [ "Seed Studio #{(index % 4) + 1} Ltd." ],
      franchises: [ ("Seed Chronicles" if number % 7 == 0), ("Seed Legends Series" if number % 11 == 0) ].compact,
      genres: number % 30 == 0 ? [] : [ %w[fps rpg strategy].fetch(index % 3) ]
    ).value!

    Catalog::StageCardSeason.new.call(
      batch_token: seed_batch, card_id: card.id,
      prestige_score: number.to_f,
      prestige_score_version: Steam::PrestigeScore::VERSION,
      rating: hidden_gem ? 98.0 : 50.0 + (index % 50),
      review_count: if hidden_gem then 500 elsif number % 12 == 0 then 250_000 else 1_000 * number end
    ).value!
  end

  season_number = Catalog::DraftSeasonNumber.call
  Catalog::PromoteStagedBatch.new.call(batch_token: seed_batch, season_number:).value!
  Catalog::PublishSeason.new.call(number: season_number).value!
  puts "Seeded and published season #{season_number} with #{card_count} cards."
end

# Development only: thirty fake players (the ones DevSignInsController signs
# in as, "Dev Player" first), each with a few opened packs, so the
# leaderboard and the other players' pages have rows. A fake player who
# already opened a pack is left alone, so a rerun adds nothing twice.
if Rails.env.development? && Catalog::PublishedSeason.call
  players = DevSignInsController::FAKE_PLAYER_COUNT.times.map do |number|
    Accounts::SignIn.new.call(steam_id: DevSignInsController.steam_id(number),
      persona_name: DevSignInsController.persona_name(number)).value!
  end
  Game::HealBanksJob.perform_now

  already_opened = Game::Pack.where(player_id: players.map(&:id)).where.not(opened_at: nil).distinct.pluck(:player_id)
  opened = players.each_with_index.sum do |player, number|
    next 0 if already_opened.include?(player.id)

    (2 + (number * 5) % 9).times.count { Game::OpenPack.new.call(player:).success? }
  end
  Game::BackfillFortunesJob.perform_now
  puts "Seeded #{players.size} fake players who opened #{opened} packs."
end

# Development only: a few generic roadmap milestones with stories, all three
# statuses, shown and hidden, so the landing's roadmap module and the roadmap
# page have something to show. A roadmap staff already started is left alone.
if Rails.env.development? && Catalog::RoadmapMilestone.none?
  roadmap = [
    { status: "done", shown: true,
      fr: "Les fondations du jeu", en: "Game foundations",
      stories: [
        [ "done", true, "Un menu principal et des réglages", "A main menu and settings" ],
        [ "done", true, "Une sauvegarde de la progression", "Saving the player's progress" ],
        [ "done", false, "Un écran de chargement provisoire", "A placeholder loading screen" ]
      ] },
    { status: "in_progress", shown: true,
      fr: "L'exploration des niveaux", en: "Level exploration",
      stories: [
        [ "done", true, "Un déplacement fluide du personnage", "Smooth character movement" ],
        [ "in_progress", true, "Des niveaux générés à la volée", "Procedurally generated levels" ],
        [ "to_come", true, "Une carte du monde à débloquer", "A world map to unlock" ],
        [ "to_come", false, "Un mode photo", "A photo mode" ]
      ] },
    { status: "in_progress", shown: true,
      fr: "Le jeu à plusieurs", en: "Playing together",
      stories: [
        [ "in_progress", true, "Un salon pour inviter ses amis", "A lobby to invite friends" ],
        [ "to_come", true, "Des classements hebdomadaires", "Weekly leaderboards" ]
      ] },
    { status: "to_come", shown: true,
      fr: "Les outils de la communauté", en: "Community tools",
      stories: [
        [ "to_come", true, "Un éditeur de niveaux partagés", "A shared level editor" ],
        [ "to_come", true, "Des défis créés par les joueurs", "Player-made challenges" ]
      ] },
    { status: "to_come", shown: false,
      fr: "Des expériences à l'étude", en: "Experiments under study",
      stories: [
        [ "to_come", true, "Un mode narratif ramifié", "A branching story mode" ]
      ] }
  ]

  sent = roadmap.each_with_index.to_h do |entry, index|
    stories = entry[:stories].each_with_index.to_h do |(status, shown, fr, en), story_index|
      [ "new-#{story_index}", { "wording_fr" => fr, "wording_en" => en, "status" => status, "shown" => shown ? "1" : "0" } ]
    end
    [ "new-#{index}", { "wording_fr" => entry[:fr], "wording_en" => entry[:en], "status" => entry[:status], "shown" => entry[:shown] ? "1" : "0", "stories" => stories } ]
  end
  saved = Catalog::SaveRoadmap.new.call(draft: Catalog::RoadmapDraft.from_form(sent)).value!
  puts "Seeded #{saved.size} roadmap milestones."
end
