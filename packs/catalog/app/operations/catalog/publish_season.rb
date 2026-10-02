module Catalog
  # Publishes the draft season (CAP-3, AD-5): cuts its prestige scores into
  # the five rarity tiers (RarityThresholds), sets each card-season's dust
  # level from its game's age on the publication date (Dust), then makes the
  # season the published one, all in one transaction.
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
  class PublishSeason < ApplicationOperation
    def call(number:)
      transaction do
        season = step lock_draft(number)
        card_seasons = step card_seasons_of(season)
        tiers = step cut(card_seasons)
        now = Time.current
        step write_season_data(card_seasons, tiers, now)
        step build_sets(season)
        step flip(season, now)
        step publish(SeasonPublished.new(data: { season_id: season.id }), stream_name: Season.stream_name(season.id))
        season
      end
    end

    private

    # A card-season's id, prestige score and game release date.
    Row = Data.define(:id, :prestige_score, :release_date)

    def lock_draft(number)
      season = Season.draft.lock("FOR UPDATE").take
      return Failure(:no_draft) if season.nil?
      return Failure(:stale_draft) unless season.number == number

      Success(season)
    end

    def card_seasons_of(season)
      rows = CardSeason.where(season_id: season.id).joins(:card)
        .pluck(:id, :prestige_score, "catalog_cards.release_date")
        .map { |id, score, release_date| Row.new(id:, prestige_score: score, release_date:) }
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

    # Story 2.7 builds the season's sets here, before the flip.
    def build_sets(_season)
      Success()
    end

    def flip(season, now)
      season.update!(status: :published, published_at: now)
      Success(season)
    end
  end
end
