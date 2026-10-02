require "test_helper"

class Game::OperationTest < ActiveSupport::TestCase
  class Act < Game::Operation
    def call(player:)
      step require_player(player)
    end
  end

  test "an operation without a required player: keyword cannot be defined" do
    [ "", "name:", "player: nil", "player", "*args, **kwargs" ].each do |signature|
      error = assert_raises(ArgumentError, signature) do
        Class.new(Game::Operation) { class_eval("def call(#{signature}) = nil", __FILE__, __LINE__) }
      end
      assert_match(/player: keyword/, error.message)
    end
  end

  test "an operation taking a required player: keyword can be defined" do
    assert Class.new(Game::Operation) { def call(player:, card: nil) = player }
  end

  test "reopening a valid operation to redefine call(player:) does not raise" do
    klass = Class.new(Game::Operation) { def call(player:) = player }

    assert_nothing_raised { klass.class_eval { def call(player:, card: nil) = player } }
  end

  test "a valid player passes require_player" do
    player = accounts_players(:player)

    result = Act.new.call(player: player)

    assert result.success?
    assert_equal player, result.value!
  end

  test "a missing, unsaved or banned player fails with player_required" do
    [ nil, Accounts::Player.new(steam_id: "76561197960287999"), accounts_players(:banned), :player ].each do |player|
      result = Act.new.call(player: player)

      assert result.failure?, player.inspect
      assert_equal :player_required, result.failure
    end
  end

  test "player_required has a message in both locales" do
    assert_equal "errors.game.player_required", Act.failure_key(:player_required)
    %i[en fr].each do |locale|
      I18n.with_locale(locale) { assert_predicate Act.failure_message(:player_required), :present? }
    end
  end
end
