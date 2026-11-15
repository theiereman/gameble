class DivideGameMarketAmountsByOneHundred < ActiveRecord::Migration[8.1]
  TABLES = %w[game_market_settings game_market_wallets game_market_ledger_entries game_market_listings game_market_bids
    game_market_notices game_market_edition_prices game_market_daily_snapshots].freeze

  RARITIES = %w[common uncommon rare epic legendary].freeze
  SETTINGS_AMOUNTS = (%w[entrustment stamp minimum_price].product(RARITIES).map { it.join("_") } + %w[daily_cap]).freeze
  OPTIONAL_SETTINGS_AMOUNTS = %w[alert_picoins_per_player].freeze
  POSITIVE_LISTING_AMOUNTS = %w[starting_price current_price leader_maximum final_price].freeze
  ROUNDED = {
    "game_market_listings" => %w[average_after_sale],
    "game_market_notices" => %w[amount],
    "game_market_edition_prices" => %w[average],
    "game_market_daily_snapshots" => %w[created destroyed_total forfeited circulation picoins_per_active_player median_daily_earnings
      circulation_difference] + RARITIES.map { "average_price_#{it}" }
  }.freeze

  PAIRED = %w[purchase sale].freeze
  CHAINED = %w[hold release].freeze
  CREDITS = %w[mint].freeze
  DEBITS = %w[stamp commission forfeit].freeze

  WALLET_DIFFERENCES = <<~SQL.squish.freeze
    SELECT COUNT(*) FROM game_market_wallets wallets
    FULL OUTER JOIN (
      SELECT player_id, SUM(available_delta) AS available, SUM(committed_delta) AS committed FROM game_market_ledger_entries GROUP BY player_id
    ) entries ON entries.player_id = wallets.player_id
    WHERE COALESCE(wallets.available, 0) <> COALESCE(entries.available, 0) OR COALESCE(wallets.committed, 0) <> COALESCE(entries.committed, 0)
  SQL

  CIRCULATION_DIFFERENCE = <<~SQL.squish.freeze
    SELECT COALESCE(SUM(available_delta + committed_delta), 0)
      - COALESCE(SUM(available_delta) FILTER (WHERE kind = 'mint'), 0)
      - COALESCE(SUM(available_delta) FILTER (WHERE kind IN ('stamp', 'commission', 'forfeit')), 0)
    FROM game_market_ledger_entries
  SQL

  OPEN_LEADS = <<~SQL.squish.freeze
    SELECT leader_id, id, leader_maximum FROM game_market_listings WHERE status = 'open' AND leader_id IS NOT NULL
  SQL

  def up
    safety_assured do
      execute("LOCK TABLE #{TABLES.join(", ")} IN EXCLUSIVE MODE")
      balanced = balanced?
      held_before = open_leads
      convert_settings
      convert_listings_and_bids
      convert_rounded_columns
      held_after = convert_ledger
      verify(balanced, held_before, held_after)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  def self.rounded(amount) = amount.negative? ? -rounded(-amount) : (amount + 50) / 100

  def self.positive(amount)
    return -positive(-amount) if amount.negative?

    amount.zero? ? 0 : [ rounded(amount), 1 ].max
  end

  private

  def balanced? = select_value(WALLET_DIFFERENCES).to_i.zero? && select_value(CIRCULATION_DIFFERENCE).to_i.zero?

  def open_leads = select_rows(OPEN_LEADS).to_h { |player_id, listing_id, maximum| [ [ player_id, listing_id ], maximum ] }

  def convert_settings
    assign("game_market_settings", SETTINGS_AMOUNTS.map { positive_sql(it) })
    assign("game_market_settings", OPTIONAL_SETTINGS_AMOUNTS.map { positive_sql(it) })
  end

  def convert_listings_and_bids
    assign("game_market_listings", POSITIVE_LISTING_AMOUNTS.map { positive_sql(it) })
    assign("game_market_bids", %w[maximum price_after].map { positive_sql(it) })
  end

  def convert_rounded_columns
    ROUNDED.each { |table, columns| assign(table, columns.map { "#{it} = ROUND(#{it} / 100.0)" }) }
  end

  def positive_sql(column) = "#{column} = CASE WHEN #{column} > 0 THEN GREATEST(ROUND(#{column} / 100.0), 1) ELSE #{column} END"

  def assign(table, assignments) = execute("UPDATE #{table} SET #{assignments.join(", ")}")

  def convert_ledger
    rows = select_rows("SELECT id, player_id, kind, available_delta, committed_delta, listing_id FROM game_market_ledger_entries ORDER BY player_id, id")
    converted = rows.group_by { it[1] }.map { |player_id, entries| PlayerLedger.new(player_id, entries).convert }
    write_entries(converted.flat_map(&:entries))
    write_wallets(converted)
    converted.each_with_object({}) { |ledger, held| ledger.chains.each { |listing_id, committed| held[[ ledger.player_id, listing_id ]] = committed if committed.positive? } }
  end

  def write_entries(entries)
    execute("CREATE TEMPORARY TABLE converted_ledger_entries (id bigint PRIMARY KEY, available_delta bigint NOT NULL, committed_delta bigint NOT NULL) ON COMMIT DROP")
    entries.each_slice(1_000) do |slice|
      execute("INSERT INTO converted_ledger_entries VALUES #{slice.map { |id, available, committed| "(#{id}, #{available}, #{committed})" }.join(", ")}")
    end
    execute(<<~SQL.squish)
      UPDATE game_market_ledger_entries entries SET available_delta = converted.available_delta, committed_delta = converted.committed_delta
      FROM converted_ledger_entries converted WHERE converted.id = entries.id
    SQL
  end

  def write_wallets(converted)
    execute("UPDATE game_market_wallets SET available = ROUND(available / 100.0), committed = ROUND(committed / 100.0)")
    converted.each_slice(1_000) do |slice|
      values = slice.map { "(#{it.player_id}, #{it.available}, #{it.committed})" }.join(", ")
      execute(<<~SQL.squish)
        UPDATE game_market_wallets wallets SET available = converted.available, committed = converted.committed
        FROM (VALUES #{values}) AS converted (player_id, available, committed) WHERE converted.player_id = wallets.player_id
      SQL
    end
  end

  def verify(balanced, held_before, held_after)
    raise "the wallets no longer match their ledger entries" if balanced && !balanced?

    held_before.each do |lead, maximum|
      expected = self.class.positive(maximum)
      raise "lead #{lead.inspect} holds #{held_after[lead].inspect} instead of #{expected}" if balanced && held_after[lead] != expected
    end
    leading = open_leads
    leading.each { |lead, maximum| raise "lead #{lead.inspect} holds a maximum the ledger does not" if balanced && held_after[lead] != maximum }
  end

  class PlayerLedger
    attr_reader :player_id, :entries, :chains, :available

    def initialize(player_id, rows)
      @player_id = player_id
      @rows = rows
      @entries = []
      @chains = Hash.new(0)
      @old_chains = Hash.new(0)
      @available = 0
      @old_available = 0
      @unpaired = []
    end

    def committed = @chains.values.sum

    def convert
      @rows.each { |id, _player_id, kind, available, committed, listing_id| convert_entry(id, kind, available.to_i, committed.to_i, listing_id) }
      settle_on_rounded_balance
      self
    end

    private

    def convert_entry(id, kind, available, committed, listing_id)
      new_available, new_committed =
        if PAIRED.include?(kind) then [ positive(available), track(listing_id, committed, positive(committed)) ]
        elsif CHAINED.include?(kind) then chained(listing_id, available, committed)
        else unpaired(kind, available, committed)
        end
      @old_available += available
      @available += new_available
      @unpaired << [ @entries.size, kind ] unless PAIRED.include?(kind) || CHAINED.include?(kind)
      @entries << [ id, new_available, new_committed ]
    end

    def chained(listing_id, available, committed)
      raise "hold or release #{listing_id.inspect} of player #{@player_id} moves unequal amounts" unless available == -committed

      new_committed = DivideGameMarketAmountsByOneHundred.positive(@old_chains[listing_id] + committed) - @chains[listing_id]
      [ -track(listing_id, committed, new_committed), new_committed ]
    end

    def track(listing_id, committed, new_committed)
      @old_chains[listing_id] += committed
      @chains[listing_id] += new_committed
      new_committed
    end

    def unpaired(kind, available, committed)
      raise "#{kind} entry of player #{@player_id} moves committed PiCoins" unless committed.zero?

      snapped = DivideGameMarketAmountsByOneHundred.rounded(@old_available + available) - @available
      [ CREDITS.include?(kind) ? [ snapped, 0 ].max : [ snapped, 0 ].min, 0 ]
    end

    def positive(amount) = DivideGameMarketAmountsByOneHundred.positive(amount)

    def settle_on_rounded_balance
      difference = DivideGameMarketAmountsByOneHundred.rounded(@old_available) - @available
      return if difference.zero?

      index, = @unpaired.reverse.find { |at, kind| CREDITS.include?(kind) ? @entries[at][1] + difference >= 0 : @entries[at][1] + difference <= 0 }
      raise "player #{@player_id} has no entry to absorb #{difference} PiCoins of rounding" unless index

      @entries[index][1] += difference
      @available += difference
    end
  end
end
