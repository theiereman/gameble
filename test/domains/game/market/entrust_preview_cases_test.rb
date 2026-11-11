require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"

# The cases the Confier screen's preview is tested on, run here through the operation: the two must agree.
class Game::Market::EntrustPreviewCasesTest < ActiveSupport::TestCase
  include Holdings
  include MarketSettings

  CAP = 1_200_000
  CASES = JSON.parse(File.read(Rails.root.join("test/fixtures/files/entrust_preview_cases.json"))).freeze
  CARD_SEASONS = { "common" => :common_card_one, "uncommon" => :uncommon_card_one, "rare" => :rare_card_one, "epic" => :portal_one, "legendary" => :legendary_card_one }.freeze

  CASES.each do |example|
    test example.fetch("name") do
      player = accounts_players(:player)
      settings = open_market!(daily_cap: CAP, **example.fetch("values").transform_keys { :"entrustment_#{it}" })
      minted_before = CAP - example.fetch("cap_left")
      Game::Market::Mint.credit(player_id: player.id, amount: minted_before, settings_id: settings.id) if minted_before.positive?
      card_seasons = CARD_SEASONS.transform_values { catalog_card_seasons(it) }
      example.fetch("lines").each { |line| hold(player, card_seasons.fetch(line.fetch("rarity")).id, line.fetch("copies")) }
      lines = example.fetch("lines").to_h { [ card_seasons.fetch(it.fetch("rarity")).id, it.fetch("copies") ] }
      rarity_of = card_seasons.to_h { |rarity, card_season| [ card_season.id, rarity ] }
      before = [ Game::Holding.sum(:quantity), Game::Market::LedgerEntry.count, Game::Market::ArchiveDeposit.count ]

      result = Game::Market::EntrustCards.new.call(player:, lines:, settings_token: settings.token)

      if result.success?
        entrusted = Game::Market::ArchiveDeposit.where(player_id: player.id).pluck(:card_season_id, :quantity).to_h.transform_keys { rarity_of.fetch(it) }
        stayed = result.value!.stayed.to_h { [ rarity_of.fetch(it.card_season_id), it.copies ] }
        received = result.value!.minted
        assert_equal example.fetch("received"), Game::Market::Wallet.find_by!(player_id: player.id).available - minted_before
      else
        assert_equal :nothing_fits, result.failure
        entrusted = {}
        stayed = example.fetch("lines").to_h { [ it.fetch("rarity"), it.fetch("copies") ] }
        received = 0
        assert_equal before, [ Game::Holding.sum(:quantity), Game::Market::LedgerEntry.count, Game::Market::ArchiveDeposit.count ]
      end

      assert_equal example.fetch("entrusted"), entrusted
      assert_equal example.fetch("stayed"), stayed
      assert_equal example.fetch("received"), received
    end
  end
end
