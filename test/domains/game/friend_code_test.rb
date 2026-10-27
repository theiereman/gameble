require "test_helper"

class Game::FriendCodeTest < ActiveSupport::TestCase
  setup { @player = accounts_players(:player) }

  def new_player
    Accounts::Player.create!(steam_id: "7656119#{SecureRandom.random_number(10**10).to_s.rjust(10, "0")}", persona_name: "Zed")
  end

  test "a random code is two groups of four characters from the alphabet" do
    100.times { assert_match Game::FriendCode::FORMAT, Game::FriendCode.random_code }
  end

  test "creating a code is idempotent" do
    player = new_player
    first = Game::CreateFriendCode.new.call(player:).value!

    assert_match Game::FriendCode::FORMAT, first.code
    assert_equal first, Game::CreateFriendCode.new.call(player:).value!
    assert_equal 1, Game::FriendCode.where(player_id: player.id).count
  end

  test "a collision with another player's code draws another" do
    player = new_player
    codes = [ "7K2Q-F3NX", "2222-3333" ]
    original = Game::FriendCode.method(:random_code)
    Game::FriendCode.define_singleton_method(:random_code) { codes.shift }
    begin
      assert_equal "2222-3333", Game::CreateFriendCode.new.call(player:).value!.code
    ensure
      Game::FriendCode.define_singleton_method(:random_code, original)
    end
  end

  test "two players never share a code" do
    codes = Array.new(5) { Game::CreateFriendCode.new.call(player: new_player).value!.code }

    assert_equal 5, codes.uniq.size
  end

  test "a missing player has no code" do
    assert_equal Dry::Monads::Failure(:player_required), Game::CreateFriendCode.new.call(player: Accounts::Player.new)
  end

  test "an account deleted after it was read gets no code and recreates none" do
    player = new_player
    stale = Accounts::Player.find(player.id)

    Accounts::DeletePlayer.new.call(player:).value!

    assert_predicate stale, :persisted?
    assert_equal Dry::Monads::Failure(:player_required), Game::CreateFriendCode.new.call(player: stale)
    assert_not Game::FriendCode.exists?(player_id: player.id)
  end

  test "the database refuses a malformed or repeated code" do
    other = accounts_players(:moderator)
    assert_raises(ActiveRecord::StatementInvalid) do
      Game::FriendCode.transaction(requires_new: true) { Game::FriendCode.where(player_id: other.id).update_all(code: "lower-case") }
    end
    assert_raises(ActiveRecord::RecordNotUnique) do
      Game::FriendCode.transaction(requires_new: true) { Game::FriendCode.where(player_id: other.id).update_all(code: "7K2Q-F3NX") }
    end
  end

  test "the friend code of a player, nil for a visitor" do
    assert_equal "7K2Q-F3NX", Game::FriendCodeOf.call(@player)
    assert_nil Game::FriendCodeOf.call(nil)
  end

  test "friends are the other side of the player's friendships, banned ones left out" do
    other = accounts_players(:moderator)
    banned = accounts_players(:banned)
    [ other, banned ].each { |friend| Game::Friendship.create!(low_player_id: [ @player.id, friend.id ].min, high_player_id: [ @player.id, friend.id ].max) }

    assert_equal [ other ], Game::FriendsOf.call(@player)
    assert_equal [ @player ], Game::FriendsOf.call(other)
    assert_empty Game::FriendsOf.call(nil)
  end

  test "a friendship is one row per pair, the lower id first" do
    low, high = [ @player.id, accounts_players(:moderator).id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)

    assert_raises(ActiveRecord::RecordNotUnique) do
      Game::Friendship.transaction(requires_new: true) { Game::Friendship.create!(low_player_id: low, high_player_id: high) }
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Game::Friendship.transaction(requires_new: true) { Game::Friendship.create!(low_player_id: high, high_player_id: low) }
    end
  end

  test "the backfill gives a code to every player without one, banned included, and reruns as a no-op" do
    player = new_player
    Game::FriendCode.where(player_id: accounts_players(:banned).id).delete_all

    assert_equal 2, Game::BackfillFriendCodesJob.players_without_a_code
    Game::BackfillFriendCodesJob.perform_now
    assert_equal 0, Game::BackfillFriendCodesJob.players_without_a_code
    code = Game::FriendCodeOf.call(player)
    Game::BackfillFriendCodesJob.perform_now
    assert_equal code, Game::FriendCodeOf.call(player)
  end

  # Accounts::PlayersInBatches yields `players` as its one batch while the
  # block runs, as a batch read before they were deleted would.
  def reading_the_batch(players)
    original = Accounts::PlayersInBatches.method(:call)
    Accounts::PlayersInBatches.define_singleton_method(:call) { |**, &block| block.call(players) }
    yield
  ensure
    Accounts::PlayersInBatches.define_singleton_method(:call, original)
  end

  test "the backfill skips unreported a player deleted since their batch was read" do
    player = new_player
    stale = Accounts::Player.find(player.id)
    Accounts::DeletePlayer.new.call(player:).value!

    reading_the_batch([ stale ]) do
      assert_no_error_reported { Game::BackfillFriendCodesJob.perform_now }
    end

    assert_not Game::FriendCode.exists?(player_id: player.id)
  end

  test "signing up gives the new player a code" do
    result = Accounts::SignIn.new.call(steam_id: "76561198000000999", persona_name: "Neo")
    player = result.value!.respond_to?(:player) ? result.value!.player : result.value!

    assert_match Game::FriendCode::FORMAT, Game::FriendCodeOf.call(player)
  end
end
