require "test_helper"
require_relative "../../support/decks"
require_relative "../../support/market"
require_relative "../../support/market_auctions"

# A trade or a listing releases only the copies it reserved: when it ends, the copy a deck blocks stays reserved and
# the deck keeps its card, whether the trade is declined, cancelled, expired or dropped as its proposer goes private,
# and whether the listing is cancelled or sold.
class Game::DeckBlockReleasesTest < ActiveSupport::TestCase
  include Decks
  include MarketAuctions
  include MarketSettings

  setup do
    @player = accounts_players(:player)
    @friend = accounts_players(:moderator)
    low, high = [ @player.id, @friend.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
    @card, @wanted = ranked_cards(@player, 2, quantity: 2)
    hold(@friend, @wanted)
    @deck = Game::CreateDeck.new.call(player: @player, name: "Vieux briscards").value!
    Game::AddCardToDeck.new.call(player: @player, token: @deck.token, card_season_id: @card).value!
  end

  def propose = Game::ProposeTrade.new.call(player: @player, recipient: @friend, offer: { @card => 1 }, request: { @wanted => 1 }).value!

  def revision(trade) = Game::Trade.find(trade.id).revision

  def assert_deck_block_kept
    assert_equal 1, reserved_of(@player, @card)
    assert_equal({ 1 => @card }, Game::DeckSlots.call(@deck))
  end

  def list
    settings = open_market!(first_opened_at: 1.day.ago)
    fund!(@player, 1_000_000)
    rarity = Catalog::CardSeason.where(id: @card).pick(:rarity).to_sym
    Game::Market::ListCard.new.call(player: @player, card_season_id: @card, starting_price: settings.minimum_price(rarity),
      duration_hours: settings.duration_short_hours, settings_token: settings.token).value!
  end

  test "a trade may offer the copy no deck blocks, never both" do
    assert_equal :insufficient_copies,
      Game::ProposeTrade.new.call(player: @player, recipient: @friend, offer: { @card => 2 }, request: { @wanted => 1 }).failure

    propose
    assert_equal 2, reserved_of(@player, @card)
  end

  test "a friend may ask for every copy but the one a deck blocks" do
    ask = ->(copies) { Game::ProposeTrade.new.call(player: @friend, recipient: @player, offer: { @wanted => 1 }, request: { @card => copies }) }

    assert_equal :request_exceeds_holdings, ask.(2).failure
    assert ask.(1).success?
  end

  test "the asker's own deck of the edition takes nothing from what they may ask for" do
    hold(@friend, @card)
    their_deck = Game::CreateDeck.new.call(player: @friend).value!
    Game::AddCardToDeck.new.call(player: @friend, token: their_deck.token, card_season_id: @card).value!

    assert Game::ProposeTrade.new.call(player: @friend, recipient: @player, offer: {}, request: { @card => 1 }).success?
  end

  test "a declined trade frees only its copy" do
    trade = propose
    assert Game::DeclineTrade.new.call(player: @friend, trade_id: trade.id, revision: revision(trade)).success?

    assert_deck_block_kept
  end

  test "a cancelled trade frees only its copy" do
    trade = propose
    assert Game::CancelTrade.new.call(player: @player, trade_id: trade.id).success?

    assert_deck_block_kept
  end

  test "an expired trade frees only its copy" do
    trade = propose
    travel 8.days do
      assert Game::ExpireTrade.new.call(player: @player, trade_id: trade.id).success?
    end

    assert_deck_block_kept
  end

  test "going private drops the open trades and keeps the deck block" do
    trade = propose
    assert Accounts::SetVisibility.new.call(player: @player, visibility: "private").success?

    assert_equal "cancelled", Game::Trade.find(trade.id).status
    assert_deck_block_kept
  end

  test "a cancelled listing frees only its copy" do
    listing = list
    assert_equal 2, reserved_of(@player, @card)

    assert Game::Market::CancelListing.new.call(player: @player, listing_id: listing.id).success?

    assert_deck_block_kept
  end

  test "a sold listing takes its copy, and the deck keeps the other" do
    listing = list
    buyer = @friend
    fund!(buyer, 1_000_000)
    lead!(listing, buyer, listing.starting_price * 2)

    travel_to(listing.ends_at + 1.minute) do
      assert Game::Market::CloseAuction.new.call(player: @player, listing_id: listing.id).success?
    end

    assert_equal "sold", listing.reload.status
    assert_equal 1, Game::Holding.find_by!(player_id: @player.id, card_season_id: @card).quantity
    assert_deck_block_kept
  end
end
