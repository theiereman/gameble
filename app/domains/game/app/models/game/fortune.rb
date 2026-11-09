module Game
  class Fortune < ApplicationRecord
    self.table_name = "game_fortunes"

    PACK_COLUMNS = { "regular" => :regular_packs, "bonus" => :bonus_packs, "reward" => :reward_packs }.freeze

    CARD_COLUMNS = Catalog::Rarity::TIERS.transform_values { |rarity| :"#{rarity}_cards" }.freeze

    SUMMED = [ *PACK_COLUMNS.values, *CARD_COLUMNS.values, :actual_points, :expected_points, :variance ].freeze

    scope :all_time, -> { where(week_start: nil) }
    scope :week_of, ->(time) { where(week_start: WeeklyGoal.week_start(time)) }
    scope :of_period, ->(period, now) do
      case period
      when :week then week_of(now)
      when :last_week then week_of(now - 1.week)
      else all_time
      end
    end
    scope :listed, -> { where(player_id: Accounts::Player.in_good_standing.where.not(visibility: :private).select(:id)) }
    scope :ranked, -> { listed.order(z_score: :desc, player_id: :asc) }
    scope :ahead_of, ->(fortune) { where("z_score > :z OR (z_score = :z AND player_id < :id)", z: fortune.z_score, id: fortune.player_id) }

    def self.record_opening(pack_id)
      pack = Pack.find(pack_id)
      rows = tally([ pack ]).map { |week_start, sums| row(pack.player_id, week_start, sums, pack.opened_at) }
      upsert_all(rows, unique_by: %i[player_id week_start], record_timestamps: false,
        on_duplicate: Arel.sql((SUMMED.map { |column| "#{column} = game_fortunes.#{column} + excluded.#{column}" } +
          [ "updated_at = excluded.updated_at" ]).join(", ")))
    end

    def self.rebuild(player_id, now)
      packs = Pack.where(player_id:).where.not(opened_at: nil).select(:id, :player_id, :kind, :card_season_ids, :opened_at).to_a
      where(player_id:).delete_all
      return if packs.empty?

      insert_all!(tally(packs).map { |week_start, sums| row(player_id, week_start, sums, now) }, record_timestamps: false)
    end

    def self.tally(packs)
      tiers = Catalog::CardSeasonTiers.call(packs.flat_map(&:card_season_ids))
      guaranteed_pack_id = FirstSessionGuarantee.guaranteed_pack_id(packs.first.player_id)
      packs.each_with_object(Hash.new { |sums, key| sums[key] = SUMMED.index_with(0) }) do |pack, sums|
        contribution = contribution_of(pack, tiers, guaranteed_pack_id)
        [ nil, WeeklyGoal.week_start(pack.opened_at) ].each do |week_start|
          contribution.each { |column, amount| sums[week_start][column] += amount }
        end
      end
    end

    def self.contribution_of(pack, tiers, guaranteed_pack_id)
      expectation = LuckOdds.of(pack.id == guaranteed_pack_id ? :regular_with_guarantee : pack.kind)
      drawn = pack.card_season_ids.map { |id| tiers.fetch(id, 1) }
      { PACK_COLUMNS.fetch(pack.kind) => 1, actual_points: drawn.sum { |tier| LuckOdds.points(tier) },
        expected_points: expectation.points, variance: expectation.variance }
        .merge(drawn.tally.to_h { |tier, count| [ CARD_COLUMNS.fetch(tier), count ] })
    end

    def self.row(player_id, week_start, sums, now)
      { player_id:, week_start:, **sums, created_at: now, updated_at: now }
    end

    private_class_method :tally, :contribution_of, :row

    def packs_by_kind = PACK_COLUMNS.transform_values { |column| public_send(column) }

    def cards_by_tier = CARD_COLUMNS.transform_values { |column| public_send(column) }
  end
end
