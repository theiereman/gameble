module Catalog
  # Publishes the draft season (CAP-3, AD-5): cuts its prestige scores into
  # the five rarity tiers (RarityThresholds), sets each card-season's dust
  # level from its game's age on the publication date (Dust), builds its sets
  # (SetBuilder), then makes the season the published one, all in one
  # transaction.
  #
  # The draft is locked FOR UPDATE, so publishing waits for the upserts in
  # flight (they hold it FOR SHARE) and a second publish finds no draft. The
  # caller sends the number of the draft it saw: another draft is refused.
  # Every guard runs before any write. Season data is written in bulk while
  # the season is still a draft; once published, it is frozen (CardSeason).
  # The next upsert opens a new draft.
  #
  # Publishes Catalog::SeasonPublished.
  #
  #   Catalog::PublishSeason.new.call(number: 2)
  #   # => Success(season) | Failure(:no_draft) | Failure(:stale_draft)
  #   #    | Failure(:empty_season) | Failure(:empty_tier)
  #
  # Raises ArgumentError, rolling the publication back, if a set key fails
  # Set::KEY_FORMAT; UpsertDraftCard refuses such genres, so only a writer
  # that bypasses it can cause this.
  class PublishSeason < ApplicationOperation
    def call(number:)
      transaction do
        season = step lock_draft(number)
        rows = step rows_of(season)
        tiers = step cut(rows)
        now = Time.current
        step write_season_data(rows, tiers, now)
        step build_sets(season, rows)
        step flip(season, now)
        step publish(SeasonPublished.new(data: { season_id: season.id }), stream_name: Season.stream_name(season.id))
        season
      end
    end

    private

    # Memberships are inserted this many at a time.
    MEMBERSHIP_SLICE = 5_000

    def lock_draft(number)
      season = Season.draft.lock("FOR UPDATE").take
      return Failure(:no_draft) if season.nil?
      return Failure(:stale_draft) unless season.number == number

      Success(season)
    end

    def rows_of(season)
      rows = SeasonRows.call(season.id)
      rows.empty? ? Failure(:empty_season) : Success(rows)
    end

    def cut(card_seasons)
      tiers = RarityThresholds.tiers(card_seasons.map(&:prestige_score))
      tiers ? Success(tiers) : Failure(:empty_tier)
    end

    # One UPDATE per (rarity, dust level) pair. The publication date is the
    # UTC date of the publication time.
    def write_season_data(card_seasons, tiers, now)
      published_on = now.utc.to_date
      card_seasons.zip(tiers)
        .group_by { |row, tier| [ tier, Dust.level_for(row.release_date, on: published_on) ] }
        .each do |(rarity, dust_tier), pairs|
          CardSeason.where(id: pairs.map { |row, _| row.id }).update_all(rarity:, dust_tier:, updated_at: now)
        end
      Success()
    end

    # The season's sets and their memberships (positions 1..n), written in
    # bulk while the season is still a draft. A key outside Set::KEY_FORMAT
    # raises, which rolls the publication back. A draft that yields no set
    # still publishes.
    def build_sets(season, rows)
      built = SetBuilder.call(rows)
      return Success() if built.empty?

      invalid = built.reject { |set| Set::KEY_FORMAT.match?(set[:key]) }
      raise ArgumentError, "set keys outside KEY_FORMAT: #{invalid.map { |set| [ set[:kind], set[:key] ] }.inspect}" if invalid.any?

      ids = Set.insert_all!(built.map { |set| set.slice(:kind, :key, :params).merge(season_id: season.id) }, returning: %w[id kind key])
        .rows.to_h { |id, kind, key| [ [ kind, key ], id ] }
      built.flat_map do |set|
        set_id = ids.fetch([ set[:kind], set[:key] ])
        set[:members].each_with_index.map { |card_season_id, index| { set_id:, card_season_id:, position: index + 1 } }
      end.each_slice(MEMBERSHIP_SLICE) { |slice| SetMembership.insert_all!(slice) }
      Success()
    end

    def flip(season, now)
      season.update!(status: :published, published_at: now)
      Success(season)
    end
  end
end
