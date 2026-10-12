module Catalog
  # Publishes the draft season: cuts its prestige scores into the five
  # rarity tiers (RarityThresholds), gives each card-season its number in
  # the season and its main theme (the card's first genre), builds its sets
  # and their tiers (SetBuilder), then makes the season the published one,
  # all in one transaction.
  #
  # Numbers are 1..n over the season's n card-seasons, shuffled with
  # SecureRandom (or the `random:` given, for tests) over the card-seasons in
  # id order. Only this class numbers card-seasons.
  #
  # The draft is locked FOR UPDATE, so publishing waits for the upserts in
  # flight (they hold it FOR SHARE) and a second publish finds no draft. The
  # caller sends the number of the draft it saw: another draft is refused.
  # A draft whose prestige scores come from two formulas (ScoreVersions) is
  # refused until its cards are scored again by one. A draft holding a card
  # whose genre is no theme (written before themes) is refused until its
  # cards' genres are filled again, so those cards never land in the UFOs
  # unseen.
  # Every guard runs before any write. Season data is written in bulk while
  # the season is still a draft; once published, it is frozen (CardSeason).
  # The next upsert opens a new draft.
  #
  # Publishes Catalog::SeasonPublished.
  #
  #   Catalog::PublishSeason.new.call(number: 2)
  #   # => Success(season) | Failure(:no_draft) | Failure(:stale_draft)
  #   #    | Failure(:empty_season) | Failure(:mixed_score_versions) | Failure(:unknown_theme)
  #   #    | Failure(:empty_tier)
  #
  # `number_published` numbers, once, a season published before card numbers
  # existed (the expand step run by `catalog:number_seasons`), by the same
  # shuffle, under a FOR UPDATE lock of the season. It publishes no event.
  #
  #   Catalog::PublishSeason.new.number_published(number: 1)
  #   # => Success(season) | Failure(:no_published_season) | Failure(:already_numbered)
  class PublishSeason < ApplicationOperation
    operate_on :call, :number_published

    def initialize(random: SecureRandom)
      super()
      @random = random
    end

    def call(number:)
      transaction do
        season = step lock_draft(number)
        rows = step rows_of(season)
        step require_one_score_version(rows)
        step require_known_themes(rows)
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

    # Memberships are inserted this many at a time.
    MEMBERSHIP_SLICE = 5_000

    def lock_draft(number)
      season = Season.draft.lock("FOR UPDATE").take
      return Failure(:no_draft) if season.nil?
      return Failure(:stale_draft) unless season.number == number

      Success(season)
    end

    def lock_published(number)
      season = Season.published.where(number:).lock("FOR UPDATE").take
      season ? Success(season) : Failure(:no_published_season)
    end

    # The ids of the season's card-seasons, ascending, when none has a number.
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

    def require_known_themes(rows)
      rows.all? { |row| row.genres.all? { |genre| Themes.key?(genre) } } ? Success() : Failure(:unknown_theme)
    end

    def cut(card_seasons)
      tiers = RarityThresholds.tiers(card_seasons.map(&:prestige_score))
      tiers ? Success(tiers) : Failure(:empty_tier)
    end

    # One UPDATE per rarity, one per main theme, then one for the numbers.
    # The rows come in id order (SeasonRows).
    def write_season_data(card_seasons, tiers, now)
      card_seasons.zip(tiers)
        .group_by { |_row, tier| tier }
        .each do |rarity, pairs|
          CardSeason.where(id: pairs.map { |row, _| row.id }).update_all(rarity:, updated_at: now)
        end
      write_main_themes(card_seasons, now)
      number_card_seasons(card_seasons.map(&:id), now)
    end

    def write_main_themes(card_seasons, now)
      card_seasons.reject { |row| row.genres.empty? }.group_by { |row| row.genres.first }.each do |main_theme, rows|
        CardSeason.where(id: rows.map(&:id)).update_all(main_theme:, updated_at: now)
      end
    end

    # Gives the card-seasons `ids` (ascending) the numbers 1..n in a shuffled
    # order, in one UPDATE joined to the pairs (id, number).
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

    # The season's sets, their memberships (positions 1..n) and their tiers,
    # written in bulk while the season is still a draft.
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
