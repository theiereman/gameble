module ChartVersions
  NO_SNAPSHOT = "none"
  SNAPSHOT_DATED = %w[reactor rarity_prices].freeze

  SnapshotDated = Data.define(:last_day) do
    def self.current = new(last_day: Game::Market::EconomySeries.last_day)

    def version = last_day&.iso8601 || NO_SNAPSHOT

    def current?(requested) = requested == version

    def drawn_through = last_day || (Time.current.utc.to_date - 1)
  end

  def self.for(kind) = (SnapshotDated.current if SNAPSHOT_DATED.include?(kind.to_s))
end
