require "test_helper"
require Rails.root.join("db/migrate/20261120160003_grant_capacity_slots_already_used").to_s

# A player's capacity for goals, custom sets and decks: the free count plus the slots they bought, bounded by the database;
# the deploy grants as bought slots the custom sets and decks a player already keeps above the free counts.
class Game::CapacityTest < ActiveSupport::TestCase
  setup do
    @player = accounts_players(:player)
  end

  def buy(kind, bought, player: @player) = Game::CapacitySlot.create!(player_id: player.id, kind:, bought:)

  def bought(player) = Game::CapacitySlot.where(player_id: player.id).order(:kind).pluck(:kind, :bought)

  test "a player with no slot has the free counts, and so has no player" do
    assert_equal [ 5, 5, 3 ], %i[goal custom_set deck].map { Game::Capacity.limit(@player, it) }
    assert_equal 3, Game::Capacity.limit(nil, :deck)
  end

  test "a bought slot adds to the free count of its kind only" do
    buy("custom_set", 1)

    assert_equal [ 5, 6, 3 ], %i[goal custom_set deck].map { Game::Capacity.limit(@player, it) }
  end

  test "the database refuses no slot bought, slots past the ceiling, an unknown kind and a second row of a kind" do
    [ [ "goal", 0 ], [ "goal", 6 ], [ "custom_set", 6 ], [ "deck", 3 ], [ "booster", 1 ] ].each do |kind, count|
      assert_raises(ActiveRecord::StatementInvalid) { buy(kind, count) }
    end
    buy("deck", 2)
    assert_raises(ActiveRecord::StatementInvalid) { buy("deck", 1) }
  end

  test "the deploy grants the custom sets and decks a player keeps above the free counts, the library set aside" do
    keeper = @player
    modest = accounts_players(:moderator)
    { keeper => [ 7, 4 ], modest => [ 5, 3 ] }.each do |player, (sets, decks)|
      Game::CustomSet.create!(player_id: player.id, kind: Game::CustomSet::STEAM_LIBRARY)
      sets.times { Game::CustomSet.create!(player_id: player.id, kind: Game::CustomSet::CUSTOM, name: "Set #{it}") }
      decks.times { Game::Deck.create!(player_id: player.id, name: "Deck #{it}") }
    end

    ActiveRecord::Migration.suppress_messages { GrantCapacitySlotsAlreadyUsed.new.migrate(:up) }

    assert_equal [ [ "custom_set", 2 ], [ "deck", 1 ] ], bought(keeper)
    assert_empty bought(modest)
  end
end
