require "test_helper"

class Accounts::BanPlayerTest < ActiveSupport::TestCase
  setup do
    @player = accounts_players(:player)
    @moderator = accounts_players(:moderator)
    @administrator = accounts_players(:administrator)
  end

  def ban(player = @player, actor: @moderator) = Accounts::BanPlayer.new.call(actor:, player:)
  def unban(player = @player, actor: @moderator) = Accounts::UnbanPlayer.new.call(actor:, player:)

  def events(type, player = @player)
    Rails.configuration.event_store.read.stream("Accounts::Player$#{player.id}").of_type(type).to_a
  end

  def befriend(first, second)
    low, high = [ first.id, second.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
  end

  def with_failing_ban_handler
    handler = Game::Handlers::PlayerBanned
    original = handler.method(:call)
    handler.define_singleton_method(:call) { |_event| raise "the handler failed" }
    yield
  ensure
    handler.define_singleton_method(:call, original)
  end

  [ :moderator, :administrator ].each do |role|
    test "a #{role} bans a player: banned_at is set and PlayerBanned carries the player id, once" do
      result = travel_to(Time.utc(2026, 10, 8, 12)) { ban(actor: accounts_players(role)) }

      assert_equal @player, result.value!
      assert_equal Time.utc(2026, 10, 8, 12), @player.reload.banned_at
      assert_equal [ { player_id: @player.id } ], events(Accounts::PlayerBanned).map(&:data)
    end
  end

  test "a moderator bans another moderator" do
    other = Accounts::Player.create!(steam_id: "76561197960287901", role: :moderator)

    assert ban(other).success?
    assert_predicate other.reload, :banned?
  end

  test "the ban rotates the player's private stream key" do
    key = @player.stream_key

    ban

    assert_not_equal key, @player.reload.stream_key
  end

  test "a ban ends the player's friendships and invitations through the Game handler; the others stay" do
    stranger = Accounts::Player.create!(steam_id: "76561197960287902")
    befriend(@player, @moderator)
    befriend(@moderator, @administrator)
    Game::Invitation.create!(sender_id: stranger.id, recipient_id: @player.id, status: "pending")

    ban

    assert_not Game::FriendshipBetween.call(@player, @moderator)
    assert Game::FriendshipBetween.call(@moderator, @administrator)
    assert_empty Game::Invitation.where(recipient_id: @player.id)
  end

  test "a ban cancels the player's open trades" do
    portal = catalog_card_seasons(:portal_one).id
    depths = catalog_card_seasons(:rare_card_one).id
    befriend(@player, @moderator)
    Game::Holding.create!(player_id: @player.id, card_season_id: portal, quantity: 2)
    Game::Holding.create!(player_id: @moderator.id, card_season_id: depths, quantity: 1)
    trade = Game::ProposeTrade.new.call(player: @player, recipient: @moderator, offer: { portal => 1 }, request: { depths => 1 }).value!

    ban(actor: @administrator)

    assert_equal "cancelled", trade.reload.status
    assert_equal 0, Game::Holding.find_by(player_id: @player.id, card_season_id: portal).reserved
  end

  test "a handler that fails rolls the ban back, event included" do
    with_failing_ban_handler do
      assert_raises(RuntimeError) { ban }
    end

    assert_not @player.reload.banned?
    assert_empty events(Accounts::PlayerBanned)
  end

  [ :moderator, :administrator ].each do |role|
    test "a #{role} cannot ban an administrator, nor themselves" do
      actor = accounts_players(role)
      other_administrator = Accounts::Player.create!(steam_id: "76561197960287903", role: :administrator)

      assert_equal Dry::Monads::Failure(:cannot_ban_administrator), ban(other_administrator, actor:)
      assert_equal Dry::Monads::Failure(:cannot_ban_self), ban(actor, actor:)
      assert_not other_administrator.reload.banned?
      assert_not actor.reload.banned?
      assert_empty events(Accounts::PlayerBanned, other_administrator)
      assert_empty events(Accounts::PlayerBanned, actor)
    end
  end

  test "a player already banned is refused, and nothing more is published" do
    ban

    assert_equal Dry::Monads::Failure(:already_banned), ban
    assert_equal 1, events(Accounts::PlayerBanned).size
  end

  test "a stale copy of a player banned meanwhile is refused under the row lock" do
    stale = Accounts::Player.find(@player.id)
    ban

    assert_equal Dry::Monads::Failure(:already_banned), ban(stale)
    assert_equal 1, events(Accounts::PlayerBanned).size
  end

  test "no player, an unsaved or a deleted one is not found" do
    Accounts::DeletePlayer.new.call(player: @player).value!

    assert_equal Dry::Monads::Failure(:player_not_found), ban(nil)
    assert_equal Dry::Monads::Failure(:player_not_found), ban(Accounts::Player.new)
    assert_equal Dry::Monads::Failure(:player_not_found), ban(@player)
    assert_equal Dry::Monads::Failure(:player_not_found), unban(@player)
    assert_nil @player.reload.banned_at
  end

  test "only staff in good standing ban or unban" do
    banned_moderator = Accounts::Player.create!(steam_id: "76561197960287904", role: :moderator, banned_at: Time.current)
    target = accounts_players(:banned)

    [ nil, Accounts::Player.new(role: :moderator), accounts_players(:player), banned_moderator ].each do |actor|
      assert_equal Dry::Monads::Failure(:staff_required), ban(@moderator, actor:)
      assert_equal Dry::Monads::Failure(:staff_required), unban(target, actor:)
    end
    assert_not @moderator.reload.banned?
    assert_predicate target.reload, :banned?
  end

  test "a stale copy of an officer demoted or banned meanwhile neither bans nor unbans" do
    target = accounts_players(:banned)
    stale = Accounts::Player.find(@moderator.id)

    @moderator.update_columns(role: "player")
    assert_equal Dry::Monads::Failure(:staff_required), ban(actor: stale)
    assert_equal Dry::Monads::Failure(:staff_required), unban(target, actor: stale)

    @moderator.update_columns(role: "moderator", banned_at: Time.current)
    assert_equal Dry::Monads::Failure(:staff_required), ban(actor: stale)
    assert_equal Dry::Monads::Failure(:staff_required), unban(target, actor: stale)

    assert_not @player.reload.banned?
    assert_predicate target.reload, :banned?
    assert_empty events(Accounts::PlayerBanned)
    assert_empty events(Accounts::PlayerUnbanned, target)
  end

  [ :moderator, :administrator ].each do |role|
    test "a #{role} unbans a player: banned_at is cleared and PlayerUnbanned carries the player id, once" do
      ban

      assert_equal @player, unban(actor: accounts_players(role)).value!

      assert_nil @player.reload.banned_at
      assert_equal [ { player_id: @player.id } ], events(Accounts::PlayerUnbanned).map(&:data)
    end
  end

  test "a player not banned cannot be unbanned" do
    assert_equal Dry::Monads::Failure(:not_banned), unban
    assert_empty events(Accounts::PlayerUnbanned)

    ban
    unban
    assert_equal Dry::Monads::Failure(:not_banned), unban
    assert_equal 1, events(Accounts::PlayerUnbanned).size
  end

  test "an unbanned player signs in again, and can be banned again" do
    ban
    assert_equal Dry::Monads::Failure(:banned), Accounts::SignIn.new.call(steam_id: @player.steam_id)

    unban

    assert_equal @player, Accounts::SignIn.new.call(steam_id: @player.steam_id).value!
    assert ban.success?
    assert_equal 2, events(Accounts::PlayerBanned).size
  end

  test "every failure has a message in both locales" do
    codes = %i[staff_required player_not_found cannot_ban_administrator cannot_ban_self already_banned not_banned]

    %i[fr en].each do |locale|
      I18n.with_locale(locale) do
        codes.each { |code| assert I18n.exists?(Accounts::BanPlayer.failure_key(code)), "#{locale}: #{code}" }
      end
    end
  end
end
