module Game
  module CardBackShelf
    Row = Data.define(:back, :state, :season, :seasons) do
      def key = back.key
      def asset = back.asset
      def unlock = back.unlock
      def active? = state == :active
      def locked? = state == :locked
      def choosable_season? = seasons.size > 1
    end

    def self.call(player)
      active, active_season = CardBacks.active_with_season(player)
      unlocked = CardBackUnlock.where(player_id: player.id).pluck(:back).to_set
      earned = CardBackSeasons.call(player)
      CardBacks::CATALOGUE.map do |back|
        state = state(back, active:, unlocked:)
        Row.new(back:, state:, season: (active_season if state == :active), seasons: earned.fetch(back.key, []))
      end
    end

    def self.state(back, active:, unlocked:)
      if back.key == active then :active
      elsif back.key == CardBacks::STANDARD || unlocked.include?(back.key) then :unlocked
      else :locked
      end
    end

    private_class_method :state
  end
end
