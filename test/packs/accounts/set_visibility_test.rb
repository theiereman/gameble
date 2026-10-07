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
end
