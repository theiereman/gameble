module Game
  module Avatars
    DEFAULT = "default".freeze

    Avatar = Data.define(:key, :achievement) do
      def icon = "avatar-#{key.dasherize}"

      def default? = key == DEFAULT

      def free? = achievement.nil?
    end

    FREE = %w[
      mechanic pilot cartographer botanist streamer elder astronaut punk chef
      robot cat alien slime owl
    ].freeze

    UNLOCKING_ACHIEVEMENTS = {
      "novice" => "first_booster",
      "archivist" => "first_complete_set",
      "guardian" => "night_owl",
      "oracle" => "first_epic",
      "grand_master" => "boosters_500"
    }.freeze

    CATALOGUE = [
      Avatar.new(key: DEFAULT, achievement: nil),
      *FREE.map { |key| Avatar.new(key:, achievement: nil) },
      *UNLOCKING_ACHIEVEMENTS.map { |key, achievement| Avatar.new(key:, achievement:) }
    ].freeze

    BY_KEY = CATALOGUE.index_by(&:key).freeze

    def self.find(key)
      BY_KEY[key.to_s]
    end

    def self.default
      BY_KEY.fetch(DEFAULT)
    end

    def self.for_achievement(achievement)
      CATALOGUE.find { it.achievement == achievement.to_s }
    end
  end
end
