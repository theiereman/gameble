require "test_helper"
require_relative "../support/market"
require_relative "../support/market_auctions"
require_relative "../support/archive_at_reference"

# A bought copy reaches every open market and shop page: one public stream per locale, sent by a job once the transaction commits.
class ArchiveStreamTest < ActiveSupport::TestCase
  include ArchiveAtReference
  include ActionCable::TestHelper
  include ActiveJob::TestHelper
  include MarketAuctions
  include MarketSettings

  setup do
    @player = accounts_players(:player)
    @card = catalog_card_seasons(:rare_card_one)
    @settings = open_market!(archive_price_rare: 500)
    fund!(@player, 1_000)
    @stock = Game::Market::ArchiveStock.create!(card_season_id: @card.id, quantity: 2)
  end

  def buy = Game::Market::BuyFromArchives.new.call(player: @player, card_season_id: @card.id, purchase_token: SecureRandom.base58(24), settings_token: @settings.token,
    price: Game::Market::ArchivePrices.call(@settings)[:rare])

  def broadcast(locale) = broadcasts(ArchiveStream.streamables(locale).join(":")).join

  test "a purchase enqueues one job after the commit and a refused purchase none" do
    assert_enqueued_jobs(1, only: ArchiveStreamJob) { assert buy.success? }

    clear_enqueued_jobs
    assert_no_enqueued_jobs(only: ArchiveStreamJob) { assert buy.failure? }
  end

  test "the job writes the stock left in each language, naming no database id" do
    @stock.update!(quantity: 1)
    ArchiveStreamJob.perform_now([ @card.id ])

    assert_includes broadcast(:en), "1 in stock"
    assert_includes broadcast(:fr), "1 en stock"
    assert_includes broadcast(:en), "blue-depths-1"
    assert_not_includes broadcast(:en), @card.id.to_s
  end

  test "the last copy takes the tile away" do
    @stock.delete
    ArchiveStreamJob.perform_now([ @card.id ])

    assert_includes broadcast(:en), "remove"
    assert_includes broadcast(:en), "blue-depths-1"
    assert_match(/gameble-reload.{0,20}#{ArchiveStream::PANEL}/, broadcast(:en))
  end
end
