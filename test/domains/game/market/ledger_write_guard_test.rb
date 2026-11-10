require "test_helper"

class Game::Market::LedgerWriteGuardTest < ActiveSupport::TestCase
  ALLOWED = %w[
    app/domains/game/app/models/game/market/ledger.rb
    app/domains/game/app/models/game/market/wallet.rb
    app/domains/game/app/models/game/market/ledger_entry.rb
  ].freeze

  MODEL_WRITES = /\b(?:Wallet|LedgerEntry)\b\s*(?:\.\s*(?:create|insert|upsert|update|delete|destroy|new|find_or_create|find_or_initialize)\w*)/
  RELATION_WRITES = /\b(?:wallets?|ledger_entries)\b\s*(?:\.\s*(?:create|insert|upsert|update|delete|destroy|build)\w*|<<)/
  RAW_WRITES = /(?:INSERT\s+INTO|UPDATE|DELETE\s+FROM)\s+game_market_(?:wallets|ledger_entries)/i

  test "no file but Ledger writes a wallet or an entry" do
    offenders = Dir[Rails.root.join("{app,lib}/**/*.{rb,rake,erb}")].filter_map do |path|
      relative = Pathname(path).relative_path_from(Rails.root).to_s
      next if ALLOWED.include?(relative)

      source = File.read(path)
      relative if [ MODEL_WRITES, RELATION_WRITES, RAW_WRITES ].any? { source.match?(it) }
    end

    assert_empty offenders
  end

  test "the guard sees a write when there is one" do
    assert_match MODEL_WRITES, "Game::Market::Wallet.update_all(available: 1)"
    assert_match MODEL_WRITES, "LedgerEntry.insert_all!(rows)"
    assert_match RAW_WRITES, "UPDATE game_market_wallets SET available = 0"
  end
end
