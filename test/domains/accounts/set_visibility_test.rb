require "test_helper"

class Accounts::SetVisibilityTest < ActiveSupport::TestCase
  setup { @player = accounts_players(:player) }

  def set(visibility, player: @player) = Accounts::SetVisibility.new.call(player:, visibility:)

  test "a new player is public" do
    assert_equal "public", Accounts::Player.new.visibility
    assert_predicate @player, :visibility_public?
  end

  test "it stores each of the three visibilities" do
    %w[private friends_only public].each do |visibility|
      assert_equal @player, set(visibility).value!
      assert_equal visibility, @player.reload.visibility
    end
    assert set(:private).success?
    assert_predicate @player.reload, :visibility_private?
  end

  [ nil, "", "everyone", "Private", 1, [ "private" ] ].each do |visibility|
    test "#{visibility.inspect} is refused and changes nothing" do
      assert_equal Dry::Monads::Failure(:invalid_setting), set(visibility)
      assert_equal "public", @player.reload.visibility
    end
  end

  test "no player, an unsaved player and a banned one are refused" do
    assert_equal Dry::Monads::Failure(:player_required), set("private", player: nil)
    assert_equal Dry::Monads::Failure(:player_required), set("private", player: Accounts::Player.new)
    assert_equal Dry::Monads::Failure(:player_required), set("private", player: accounts_players(:banned))
  end

  test "the database refuses a value the enum does not know" do
    assert_raises(ActiveRecord::StatementInvalid) { @player.update_column(:visibility, "everyone") }
  end

  test "a failure has a message in both locales" do
    I18n.with_locale(:fr) { assert_predicate Accounts::SetVisibility.failure_message(:invalid_setting), :present? }
  end

  test "each change publishes the player and the new visibility" do
    set("friends_only").value!

    event = Rails.configuration.event_store.read.stream("Accounts::Player$#{@player.id}").of_type(Accounts::VisibilityChanged).to_a.sole
    assert_equal({ player_id: @player.id, visibility: "friends_only" }, event.data.symbolize_keys)
  end

  test "setting the visibility the player already has publishes nothing more" do
    2.times { assert_equal @player, set("private").value! }

    assert_equal 1, Rails.configuration.event_store.read.stream("Accounts::Player$#{@player.id}").of_type(Accounts::VisibilityChanged).count
    assert_predicate @player.reload, :visibility_private?
  end

  test "going private cancels the player's open trades on both sides and releases every reserved copy" do
    with_open_trades do |bob, carol, offered, asked|
      assert set("private").success?

      assert_equal %w[cancelled cancelled], Game::Trade.order(:id).pluck(:status)
      assert_equal [ 0, 0 ], [ holding(@player, offered).reserved, holding(carol, asked).reserved ]
      assert Game::FriendshipBetween.call(@player, bob), "the friendships stay"
    end
  end

  test "going friends only or public touches no trade, and going public again restores nothing" do
    with_open_trades do
      set("friends_only").value!
      set("public").value!
      assert_equal %w[open open], Game::Trade.order(:id).pluck(:status)

      set("private").value!
      set("public").value!
      assert_equal %w[cancelled cancelled], Game::Trade.order(:id).pluck(:status)
    end
  end

  private

  def with_open_trades
    bob = accounts_players(:moderator)
    carol = accounts_players(:administrator)
    offered = catalog_card_seasons(:portal_one).id
    asked = catalog_card_seasons(:rare_card_one).id
    [ bob, carol ].each do |friend|
      low, high = [ @player.id, friend.id ].minmax
      Game::Friendship.create!(low_player_id: low, high_player_id: high)
    end
    Game::Holding.create!(player_id: @player.id, card_season_id: offered, quantity: 2)
    Game::Holding.create!(player_id: bob.id, card_season_id: asked, quantity: 1)
    Game::Holding.create!(player_id: carol.id, card_season_id: asked, quantity: 1)
    Game::ProposeTrade.new.call(player: @player, recipient: bob, offer: { offered => 1 }, request: { asked => 1 }).value!
    Game::ProposeTrade.new.call(player: carol, recipient: @player, offer: { asked => 1 }, request: { offered => 1 }).value!
    assert_equal [ 1, 1 ], [ holding(@player, offered).reserved, holding(carol, asked).reserved ]
    yield bob, carol, offered, asked
  end

  def holding(player, card_season_id) = Game::Holding.find_by!(player_id: player.id, card_season_id:)
end
