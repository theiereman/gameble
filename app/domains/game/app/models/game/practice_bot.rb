module Game
  module PracticeBot
    ROLE = :opponent
    NAME = "Bot".freeze
    DECK_SIZE = Deck::SLOTS.size
    THINKING_TIME = (1.5..4.0)

    def self.player_for(human)
      Accounts::Player.find_by(bot_of_id: human.id) || Accounts::Player.create!(bot_of_id: human.id, persona_name: NAME, visibility: "private")
    rescue ActiveRecord::RecordNotUnique
      Accounts::Player.find_by!(bot_of_id: human.id)
    end

    def self.archetype_after(human, random: Random)
      previous = Duel.where(practice: true, id: DuelSeat.where(player_id: human.id).select(:duel_id)).order(id: :desc).pick(:bot_archetype)
      (DeckArchetypes::NAMES - [ previous ]).sample(random:)
    end

    def self.deck_cards(archetype) = DeckArchetypes.build(archetype, catalog).map(&:card_season_id)

    def self.thinking_time(random: Random) = random.rand(THINKING_TIME).seconds

    def self.catalog
      DuelStat.where.not(discovery_value: nil).joins("JOIN catalog_card_seasons ON catalog_card_seasons.id = game_duel_stats.card_season_id")
        .pluck(Arel.sql("game_duel_stats.card_season_id"), Arel.sql("catalog_card_seasons.card_id"),
          *DuelStat::STATS.map { Arel.sql("game_duel_stats.#{it}_percentile") })
        .map do |card_season_id, card_id, *percentiles|
          stats = DuelStat::STATS.zip(percentiles).to_h { |stat, percentile| [ stat, DuelCard::Stat.new(value: nil, percentile:, median_distance: nil) ] }
          DuelCard.new(card_season_id:, card_id:, number: 0, rarity: 0, stats:)
        end
    end
    private_class_method :catalog
  end
end
