module Game
  module GoalNeeds
    Target = Data.define(:goal_id, :position, :kind, :key, :custom_set_token, :custom_set_name, :set) do
      def custom? = !custom_set_token.nil?

      def aims_at?(kind: nil, key: nil, custom_set: nil)
        custom? ? custom_set_token == custom_set : self.kind == kind.to_s && self.key == key.to_s
      end
    end

    Need = Data.define(:target, :card_ids, :held_card_ids, :tiers) do
      delegate :goal_id, :position, :kind, :key, :custom_set_token, :custom_set_name, :set, :custom?, to: :target

      def held = held_card_ids.size

      def total = card_ids.size

      def missing_card_ids = card_ids - held_card_ids

      def complete? = total.positive? && held >= total

      def to_set_standing = SetStanding.measured(set_id: set&.id, held:, total:, tiers:)
    end

    def self.targets(player)
      rows = goal_rows(player)
      return [] if rows.empty?

      resolve(rows, Catalog::SetsByKey.sets(season: season_for(rows), keys: game_set_keys(rows)))
    end

    def self.call(player)
      rows = goal_rows(player)
      return [] if rows.empty?

      albums = Catalog::SetsByKey.call(season: season_for(rows), keys: game_set_keys(rows))
      targets = resolve(rows, albums.transform_values(&:set))
      customs = CustomSetStandings.call(player, tokens: targets.select(&:custom?).map(&:custom_set_token)).index_by(&:token)
      held = HeldGames.call(player.id, card_ids: albums.values.flat_map(&:card_ids).uniq)
      targets.map do |target|
        if target.custom?
          standing = customs.fetch(target.custom_set_token)
          Need.new(target:, card_ids: standing.card_ids, held_card_ids: standing.held_card_ids, tiers: {})
        else
          album = albums.fetch([ target.kind, target.key ])
          Need.new(target:, card_ids: album.card_ids, held_card_ids: album.card_ids.select { held.key?(it) }, tiers: album.tiers)
        end
      end
    end

    def self.goal_rows(player)
      return [] if player.nil?

      Goal.where(player_id: player.id).left_joins(:custom_set).order(:position)
        .pluck(:id, :position, :set_kind, :set_key, Arel.sql("game_custom_sets.token"), Arel.sql("game_custom_sets.name"))
    end

    def self.game_set_keys(rows)
      rows.filter_map { |_id, _position, kind, key| [ kind, key ] if kind }
    end

    def self.season_for(rows)
      Catalog::PublishedSeason.call if game_set_keys(rows).any?
    end

    def self.resolve(rows, sets)
      rows.filter_map do |id, position, kind, key, token, name|
        set = sets[[ kind, key ]] if kind
        next if kind && set.nil?

        Target.new(goal_id: id, position:, kind:, key:, custom_set_token: token, custom_set_name: name, set:)
      end
    end

    private_class_method :goal_rows, :game_set_keys, :season_for, :resolve
  end
end
