module Game
  module CustomSetStandings
    Standing = Data.define(:token, :name, :kind, :card_ids, :held_card_ids, :synced_at, :library_private_since) do
      def held = held_card_ids.size

      def total = card_ids.size

      def complete? = total.positive? && held >= total

      def custom? = kind == CustomSet::CUSTOM

      def steam_library? = kind == CustomSet::STEAM_LIBRARY

      def library_private? = !library_private_since.nil?

      def ever_synced? = !synced_at.nil? || library_private?

      def to_set_standing = SetStanding.measured(set_id: nil, held:, total:, tiers: {})
    end

    def self.call(player, tokens: nil, kind: nil)
      return [] if player.nil? || tokens&.empty?

      sets = CustomSet.where(player_id: player.id)
      sets = sets.where(token: tokens) if tokens
      sets = sets.where(kind:) if kind
      rows = sets.order(:id).pluck(:id, :token, :name, :kind, :synced_at, :library_private_since)
      return [] if rows.empty?

      games = CustomSetCardIds.call(rows.map(&:first))
      held = HeldGames.call(player.id, card_ids: games.values.flatten.uniq)
      rows.map do |id, token, name, kind, synced_at, library_private_since|
        card_ids = games.fetch(id, [])
        Standing.new(token:, name:, kind:, card_ids:, held_card_ids: card_ids.select { held.key?(it) }, synced_at:, library_private_since:)
      end
    end
  end
end
