module Game
  # The published season's card-seasons by tier, held in memory by each
  # process for the draw. The snapshot is keyed by the season's id and
  # publication time, checked against Catalog::PublishedSeason on each use:
  # a newly published season, or a database reset that reuses an id, loads
  # a new snapshot. The swap happens behind a mutex; readers take the frozen
  # snapshot as it is.
  #
  # `of` gives the snapshot of a season the caller has already read as the
  # published one, so an operation draws from the season it read once.
  #
  #   Game::DrawPool.current # => Snapshot | nil (no season published)
  #   Game::DrawPool.of(season) # => Snapshot | nil (no season)
  module DrawPool
    # `tiers`: { 1 => [card_season_id, …], …, 5 => […] }, frozen;
    # `tier_by_id`: the reverse, { card_season_id => tier }.
    Snapshot = Data.define(:key, :season_id, :tiers, :tier_by_id) do
      def tier_of(card_season_id) = tier_by_id.fetch(card_season_id)
    end

    # A published season with a tier holding no card cannot be drawn from.
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

    # Forgets the snapshot (tests).
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
