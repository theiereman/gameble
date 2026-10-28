module Catalog
  class PublishSeason < ApplicationOperation
    operate_on :call, :number_published

    def self.refusal_message(code, panel)
      case code
      when :unclassified_tags
        failure_message(code, count: panel.unclassified_count)
      when :ufo_share_over_limit
        helper = ActiveSupport::NumberHelper
        failure_message(code, share: helper.number_to_percentage(panel.ufo_share * 100, precision: 1),
          limit: helper.number_to_percentage(Themes::UFO_SHARE_LIMIT * 100, precision: 0))
      else
        failure_message(code)
      end
    end

    def initialize(random: SecureRandom)
      super()
      @random = random
    end

    def call(number:)
      transaction do
        season = step lock_draft(number)
        step require_no_staged_batch
        rows = step rows_of(season)
        step require_one_score_version(rows)
        step require_filled_sources(rows)
        step require_classified_tags(rows)
        step require_ufos_under_limit(rows)
        tiers = step cut(rows)
        now = Time.current
        step write_season_data(rows, tiers, now)
        step build_sets(season, rows)
        step flip(season, now)
        step publish(SeasonPublished.new(data: { season_id: season.id }), stream_name: Season.stream_name(season.id))
        season
      end
    end

    def number_published(number:)
      transaction do
        season = step lock_published(number)
        ids = step unnumbered_card_seasons(season)
        step number_card_seasons(ids, Time.current)
        season
      end
    end

    private

    MEMBERSHIP_SLICE = 5_000

    def lock_draft(number)
      season = Season.draft.lock("FOR UPDATE").take
      return Failure(:no_draft) if season.nil?
      return Failure(:stale_draft) unless season.number == number

      Success(season)
    end

    def require_no_staged_batch
      StagedCardSeason.exists? ? Failure(:staged_batch_waiting) : Success()
    end

    def lock_published(number)
      season = Season.published.where(number:).lock("FOR UPDATE").take
      season ? Success(season) : Failure(:no_published_season)
    end

    def unnumbered_card_seasons(season)
      card_seasons = CardSeason.where(season_id: season.id)
      return Failure(:already_numbered) if card_seasons.where.not(number: nil).exists?

      Success(card_seasons.order(:id).ids)
    end

    def rows_of(season)
      rows = SeasonRows.call(season.id)
      rows.empty? ? Failure(:empty_season) : Success(rows)
    end

    def require_one_score_version(rows)
      ScoreVersions.mixed?(rows) ? Failure(:mixed_score_versions) : Success()
    end

    def require_filled_sources(rows)
      UnfilledSources.any?(rows) ? Failure(:unfilled_sources) : Success()
    end

    def require_classified_tags(rows)
      Themes.classification.unclassified_in(rows).empty? ? Success() : Failure(:unclassified_tags)
    end

    def require_ufos_under_limit(rows)
      ufo_count = SetBuilder.ufos(rows).sum { |set| set[:members].size }
      Themes.ufo_share_over_limit?(ufo_count, rows.size) ? Failure(:ufo_share_over_limit) : Success()
    end

    def cut(card_seasons)
      tiers = RarityThresholds.tiers(card_seasons.map(&:prestige_score))
      tiers ? Success(tiers) : Failure(:empty_tier)
    end

    def write_season_data(card_seasons, tiers, now)
      number_card_seasons(card_seasons.map(&:id), now)
      card_seasons.zip(tiers)
        .group_by { |_row, tier| tier }
        .each do |rarity, pairs|
          CardSeason.where(id: pairs.map { |row, _| row.id }).update_all(rarity:, updated_at: now)
        end
      write_main_themes(card_seasons, now)
      Success()
    end

    def write_main_themes(card_seasons, now)
      card_seasons.reject { |row| row.genres.empty? }.group_by { |row| row.genres.first }.each do |main_theme, rows|
        CardSeason.where(id: rows.map(&:id)).update_all(main_theme:, updated_at: now)
      end
    end

    def number_card_seasons(ids, now)
      return Success() if ids.empty?

      numbers = (1..ids.size).to_a.shuffle(random: @random)
      pairs = CardSeason.sanitize_sql_array([
        "JOIN unnest(ARRAY[?]::bigint[], ARRAY[?]::integer[]) AS numbered(id, number) ON numbered.id = catalog_card_seasons.id",
        ids, numbers
      ])
      CardSeason.joins(pairs).update_all([ "number = numbered.number, updated_at = ?", now ])
      Success()
    end

    def build_sets(season, rows)
      built = SetBuilder.call(rows)
      ids = Set.insert_all!(built.map { |set| set.slice(:kind, :key, :params).merge(season_id: season.id) }, returning: %w[id kind key])
        .rows.to_h { |id, kind, key| [ [ kind, key ], id ] }
      built.flat_map do |set|
        set_id = ids.fetch([ set[:kind], set[:key] ])
        set[:members].each_with_index.map { |card_season_id, index| { set_id:, card_season_id:, position: index + 1 } }
      end.each_slice(MEMBERSHIP_SLICE) { |slice| SetMembership.insert_all!(slice) }
      SetTier.insert_all!(built.flat_map do |set|
        set_id = ids.fetch([ set[:kind], set[:key] ])
        set[:tiers].map { |tier, required| { set_id:, tier:, required: } }
      end)
      Success()
    end

    def flip(season, now)
      season.update!(status: :published, published_at: now)
      Success(season)
    end
  end
end
