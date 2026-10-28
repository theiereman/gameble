module Game
  module CardBackShelf
    Row = Data.define(:back, :state) do
      def key = back.key
      def asset = back.asset
      def unlock = back.unlock
      def active? = state == :active
      def locked? = state == :locked
    end

    def self.call(player)
      active = CardBacks.active_key(player)
      unlocked = CardBackUnlock.where(player_id: player.id).pluck(:back).to_set
      CardBacks::CATALOGUE.map { Row.new(back: it, state: state(it, active:, unlocked:)) }
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
