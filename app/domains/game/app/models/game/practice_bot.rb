module Game
  module PracticeBot
    ROLE = :opponent
    NAME = "Bot".freeze
    DECK_SIZE = Deck::SLOTS.size
    CANDIDATES = DECK_SIZE * 3
    SMART_SHARE = 0.5
    THINKING_TIME = (1.5..4.0)

    def self.player_for(human)
      Accounts::Player.find_by(bot_of_id: human.id) || Accounts::Player.create!(bot_of_id: human.id, persona_name: NAME, visibility: "private")
    rescue ActiveRecord::RecordNotUnique
      Accounts::Player.find_by!(bot_of_id: human.id)
    end

    def self.deck_cards
      candidates = Catalog::CardSeason.where(id: DuelStat.where.not(discovery_value: nil).select(:card_season_id))
        .order(Arel.sql("random()")).limit(CANDIDATES).pluck(:id, :card_id)
      candidates.uniq(&:last).first(DECK_SIZE).map(&:first)
    end

    def self.thinking_time(random: Random) = random.rand(THINKING_TIME).seconds

    # A bot that plays the best move half of the time and a random one otherwise, and never reads the call it answers.
    def self.call_move(rules, random: Random)
      return rules.automatic_call if random.rand < SMART_SHARE

      DuelRules::Call.new(card: rules.hand(ROLE).sample(random:), stat: rules.stats_left(ROLE).sample(random:), direction: DuelStat::DIRECTIONS.sample(random:))
    end

    def self.answer_card(rules, random: Random)
      random.rand < SMART_SHARE ? rules.automatic_answer : rules.hand(ROLE).sample(random:)
    end
  end
end
