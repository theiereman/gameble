module ChartVersions
  NO_SNAPSHOT = "none"
  SNAPSHOT_DATED = %w[reactor rarity_prices].freeze

  SnapshotDated = Data.define(:last_day) do
    def self.current = new(last_day: Game::Market::EconomySeries.last_day)

    def version = last_day&.iso8601 || NO_SNAPSHOT

    def current?(requested) = requested == version

    def drawn_through = last_day || (Time.current.utc.to_date - 1)
  end

  EditionSales = Data.define(:slug, :season_number, :card_season_id, :fingerprint) do
    def self.of(slug:, season_number:)
      card_season_id = Catalog::PublishedCardSeasonId.call(slug:, season_number:)
      fingerprint = Game::Market::EditionSales.fingerprint(card_season_id) if card_season_id
      new(slug:, season_number:, card_season_id:, fingerprint:) if fingerprint
    end

    def self.requested(version)
      season_number, _sales, _refreshed, slug = version.to_s.split("-", 4)
      of(slug:, season_number: Integer(season_number, exception: false)) if slug.present?
    end

    def version = [ season_number, fingerprint.sales_used, fingerprint.refreshed_at.to_i, slug ].join("-")

    def current?(requested) = requested == version

    def drawn_at = fingerprint.refreshed_at
  end

  def self.for(kind, requested = nil)
    if SNAPSHOT_DATED.include?(kind.to_s) then SnapshotDated.current
    elsif kind.to_s == "edition_sales" then EditionSales.requested(requested)
    end
  end
end
