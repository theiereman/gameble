module Game
  module Avatars
    DEFAULT = "default".freeze

    Avatar = Data.define(:key, :achievement, :administrator_only) do
      def initialize(key:, achievement: nil, administrator_only: false) = super

      def icon = "avatar-#{key.dasherize}"

      def default? = key == DEFAULT

      def free? = achievement.nil? && !administrator_only

      def available_to?(player) = !administrator_only || player.administrator?

      def open_to?(player, earned_achievements)
        available_to?(player) && (achievement.nil? || earned_achievements.include?(achievement))
      end
    end

    FREE = %w[
      mechanic pilot cartographer botanist streamer elder astronaut punk chef
      robot cat alien slime owl
    ].freeze

    UNLOCKING_ACHIEVEMENTS = {
      "novice" => "first_booster",
      "archivist" => "first_complete_set",
      "guardian" => "night_owl",
      "oracle" => "first_epic"
    }.freeze

    ADMINISTRATOR_ONLY = %w[grand_master].freeze

    CATALOGUE = [
      Avatar.new(key: DEFAULT),
      *FREE.map { |key| Avatar.new(key:) },
      *UNLOCKING_ACHIEVEMENTS.map { |key, achievement| Avatar.new(key:, achievement:) },
      *ADMINISTRATOR_ONLY.map { |key| Avatar.new(key:, administrator_only: true) }
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

    def self.available_to(player)
      CATALOGUE.select { it.available_to?(player) }
    end
  end
end
