module Game
  # The published season's card-seasons by tier, held in memory by each
  # process for the draw (AD-7). The snapshot is keyed by the season's id and
  # publication time, checked against Catalog::PublishedSeason on each use:
  # a newly published season, or a database reset that reuses an id, loads
  # a new snapshot. The swap happens behind a mutex; readers take the frozen
  # snapshot as it is.
  #
  #   Game::DrawPool.current # => Snapshot | nil (no season published)
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

    # Tries at reading the season and its card-seasons consistently: a
    # publication between the two reads makes the next try.
    ATTEMPTS = 3

    def self.current
      ATTEMPTS.times do
        season = Catalog::PublishedSeason.call
        return nil if season.nil?

        key = [ season.id, season.published_at ]
        snapshot = @snapshot
        return snapshot if snapshot&.key == key

        snapshot = MUTEX.synchronize do
          @snapshot = build(key) || @snapshot unless @snapshot&.key == key
          @snapshot
        end
        return snapshot if snapshot&.key == key
      end
      raise "the published season kept changing while the draw pool loaded"
    end

    # Forgets the snapshot (tests).
    def self.reset!
      MUTEX.synchronize { @snapshot = nil }
    end

    # The snapshot of the season `key` names, or nil when another season was
    # published in the meantime.
    def self.build(key)
      published = Catalog::PublishedCardSeasonsByTier.call
      return nil unless published && published.fetch(:season_id) == key.first

      tiers = published.fetch(:tiers)
      empty = tiers.select { |_, ids| ids.empty? }.keys
      raise EmptyTier, "season #{key.first} has no card in tier(s) #{empty.join(", ")}" if empty.any?

      tiers = tiers.transform_values { |ids| ids.dup.freeze }.freeze
      tier_by_id = tiers.flat_map { |tier, ids| ids.map { |id| [ id, tier ] } }.to_h.freeze
      Snapshot.new(key:, season_id: key.first, tiers:, tier_by_id:)
    end

    private_class_method :build
  end
end
