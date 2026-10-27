module Game
  module DrawPool
    Snapshot = Data.define(:key, :season_id, :tiers, :tier_by_id) do
      def tier_of(card_season_id) = tier_by_id.fetch(card_season_id)
    end

    class EmptyTier < StandardError; end

    MUTEX = Mutex.new
    @snapshot = nil

    def self.current
      of(Catalog::PublishedSeason.call)
    end

    def self.of(season)
      return nil if season.nil?

      key = [ season.id, season.published_at ]
      snapshot = @snapshot
      return snapshot if snapshot&.key == key

      MUTEX.synchronize do
        @snapshot = build(season, key) unless @snapshot&.key == key
        @snapshot
      end
    end

    def self.reset!
      MUTEX.synchronize { @snapshot = nil }
    end

    def self.build(season, key)
      tiers = Catalog::PublishedCardSeasonsByTier.call(season).fetch(:tiers)
      empty = tiers.select { |_, ids| ids.empty? }.keys
      raise EmptyTier, "season #{season.id} has no card in tier(s) #{empty.join(", ")}" if empty.any?

      tiers = tiers.transform_values { |ids| ids.dup.freeze }.freeze
      tier_by_id = tiers.flat_map { |tier, ids| ids.map { |id| [ id, tier ] } }.to_h.freeze
      Snapshot.new(key:, season_id: season.id, tiers:, tier_by_id:)
    end

    private_class_method :build
  end
end
