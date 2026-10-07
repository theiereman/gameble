require "test_helper"
require_relative "../../support/game_packs"

# Game::FillBank (R1, R3, AD-7): ten regular packs of five cards, once.
class Game::FillBankTest < ActiveSupport::TestCase
  include GamePacks

  setup do
    Game::DrawPool.reset!
    @player = accounts_players(:player)
  end

  def packs = Game::Pack.where(player_id: @player.id)

  test "an empty bank gets ten regular packs of five cards from the published season, available now, and BankFilled" do
    now = Time.current.change(usec: 0)

    result = travel_to(now) { Game::FillBank.new.call(player: @player) }

    assert result.success?
    assert_equal 10, result.value!
    assert_equal 10, packs.count
    packs.each do |pack|
      assert_predicate pack, :regular?
      assert_equal catalog_seasons(:one).id, pack.season_id
      assert_equal 5, pack.card_season_ids.size
      assert_empty pack.card_season_ids - fixture_tier_ids
      assert_equal now, pack.available_at
      assert_nil pack.opened_at
      assert_predicate pack.token, :present?
    end
    assert_equal 10, packs.distinct.count(:token)
    events = game_events(@player)
    assert_equal [ Game::BankFilled ], events.map(&:class)
    assert_equal({ player_id: @player.id }, events.first.data)
  end

  test "a player who has a bank gets nothing more and no event" do
    Game::FillBank.new.call(player: @player).value!

    result = Game::FillBank.new.call(player: @player)

    assert_equal 0, result.value!
    assert_equal 10, packs.count
    assert_equal 1, game_events(@player, Game::BankFilled).size
  end

  test "a player whose packs are all opened still counts as having had a bank" do
    create_pack(@player, opened_at: 1.hour.ago)

    assert_equal 0, Game::FillBank.new.call(player: @player).value!
    assert_equal 1, packs.count
    assert_empty game_events(@player)
  end

  test "with no published season nothing is filled and nothing is published" do
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)

    result = Game::FillBank.new.call(player: @player)

    assert_equal 0, result.value!
    assert_equal 0, packs.count
    assert_empty game_events(@player)
  end

  test "a missing or banned player fails with player_required" do
    [ nil, accounts_players(:banned) ].each do |player|
      result = Game::FillBank.new.call(player:)

      assert_equal :player_required, result.failure
    end
    assert_equal 0, Game::Pack.unopened.count
  end

  test "the sign-up handler fills the bank, and raises when the fill fails" do
    Game::Handlers::PlayerRegistered.call(Accounts::PlayerRegistered.new(data: { player_id: @player.id }))
    assert_equal 10, packs.count

    assert_raises(Dry::Monads::UnwrapError) do
      Game::Handlers::PlayerRegistered.call(Accounts::PlayerRegistered.new(data: { player_id: accounts_players(:banned).id }))
    end
  end
end
