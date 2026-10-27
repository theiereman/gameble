require "test_helper"
require_relative "../../support/game_packs"

# Moving a showcased card one place earlier or later: it swaps with its
# neighbour, and the showcase's places come back as 0..n-1.
class Game::MoveShowcaseCardTest < ActiveSupport::TestCase
  include GamePacks

  setup do
    @player = accounts_players(:player)
    @cards = fixture_tier_ids
  end

  def showcase(card_season_ids)
    card_season_ids.each do |card_season_id|
      Game::Holding.create!(player_id: @player.id, card_season_id:, quantity: 1)
      Game::AddToShowcase.new.call(player: @player, card_season_id:).value!
    end
  end

  def move(card_season_id, direction, player: @player)
    Game::MoveShowcaseCard.new.call(player:, card_season_id:, direction:)
  end

  def places = Game::ShowcaseEntry.where(player_id: @player.id).order(:position, :id).pluck(:card_season_id, :position)

  def writes = Game::ShowcaseEntry.where(player_id: @player.id).order(:id).pluck(:position, :updated_at) + [ Rails.configuration.event_store.read.count ]

  test "a card moved later swaps with the next one, with one event" do
    a, b, c = @cards.first(3)
    showcase([ a, b, c ])

    result = move(a, :later)

    assert result.success?
    assert_equal [ [ b, 0 ], [ a, 1 ], [ c, 2 ] ], places
    event = game_events(@player, Game::ShowcaseCardMoved).sole
    assert_equal({ player_id: @player.id, card_season_id: a, position: 1 }, event.data)
  end

  test "a card moved earlier to the first place becomes the hub's card" do
    a, b, c = @cards.first(3)
    showcase([ a, b, c ])

    move(b, "earlier").value!

    assert_equal [ [ b, 0 ], [ a, 1 ], [ c, 2 ] ], places
    assert_equal b, Game::ChosenShowcase.call(@player).first
  end

  test "the first card moved earlier or the last moved later is refused" do
    showcase(@cards.first(3))

    assert_no_changes -> { writes } do
      assert_equal :showcase_edge, move(@cards[0], :earlier).failure
      assert_equal :showcase_edge, move(@cards[2], :later).failure
    end
  end

  test "a card not in the showcase is refused" do
    showcase(@cards.first(2))

    assert_no_changes -> { writes } do
      assert_equal :card_not_showcased, move(@cards[3], :later).failure
    end
  end

  test "an unknown direction is refused" do
    showcase(@cards.first(2))

    assert_no_changes -> { writes } do
      [ :up, "sideways", nil, 1 ].each do |direction|
        assert_equal :unknown_direction, move(@cards[0], direction).failure
      end
    end
  end

  test "a visitor, a banned or a deleted player is refused" do
    showcase(@cards.first(2))

    assert_no_changes -> { writes } do
      assert_equal :player_required, move(@cards[0], :later, player: nil).failure
      assert_equal :player_required, move(@cards[0], :later, player: accounts_players(:banned)).failure
      @player.update!(deleted_at: Time.current, steam_id: nil)
      assert_equal :player_required, move(@cards[0], :later).failure
    end
  end

  test "a gap or a shared place is read in order of place then id, and the move renumbers 0..n-1" do
    showcase(@cards.first(4))
    entries = Game::ShowcaseEntry.where(player_id: @player.id)
    entries.where(card_season_id: @cards[1]).update_all(position: 3)
    entries.where(card_season_id: @cards[2]).update_all(position: 3)
    entries.where(card_season_id: @cards[3]).update_all(position: 4)

    move(@cards[3], :earlier).value!

    assert_equal [ [ @cards[0], 0 ], [ @cards[1], 1 ], [ @cards[3], 2 ], [ @cards[2], 3 ] ], places
  end
end
