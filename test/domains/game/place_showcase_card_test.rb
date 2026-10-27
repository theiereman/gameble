require "test_helper"
require_relative "../../support/game_packs"

# Putting a showcased card at the place it was dropped: the cards between
# shift one place, and the showcase's places come back as 0..n-1.
class Game::PlaceShowcaseCardTest < ActiveSupport::TestCase
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

  def place(card_season_id, position, player: @player)
    Game::PlaceShowcaseCard.new.call(player:, card_season_id:, position:)
  end

  def places = Game::ShowcaseEntry.where(player_id: @player.id).order(:position, :id).pluck(:card_season_id, :position)

  def writes = Game::ShowcaseEntry.where(player_id: @player.id).order(:id).pluck(:position, :updated_at) + [ Rails.configuration.event_store.read.count ]

  test "a card dropped later takes that place, the cards between shift earlier, with one event" do
    a, b, c, d = @cards.first(4)
    showcase([ a, b, c, d ])

    result = place(a, 2)

    assert result.success?
    assert_equal [ [ b, 0 ], [ c, 1 ], [ a, 2 ], [ d, 3 ] ], places
    event = game_events(@player, Game::ShowcaseCardMoved).sole
    assert_equal({ player_id: @player.id, card_season_id: a, position: 2 }, event.data)
  end

  test "a card dropped first becomes the hub's card, the cards before it shifting later" do
    a, b, c, d = @cards.first(4)
    showcase([ a, b, c, d ])

    place(d, 0).value!

    assert_equal [ [ d, 0 ], [ a, 1 ], [ b, 2 ], [ c, 3 ] ], places
    assert_equal d, Game::ChosenShowcase.call(@player).first
  end

  test "a card dropped where it stands keeps the order" do
    a, b, c = @cards.first(3)
    showcase([ a, b, c ])

    place(b, 1).value!

    assert_equal [ [ a, 0 ], [ b, 1 ], [ c, 2 ] ], places
  end

  test "a place outside the showcase, or not a whole number, is refused" do
    showcase(@cards.first(3))

    assert_no_changes -> { writes } do
      [ -1, 3, 5, nil, "1", 1.0 ].each do |position|
        assert_equal :position_out_of_range, place(@cards[0], position).failure
      end
    end
  end

  test "a card not in the showcase is refused" do
    showcase(@cards.first(2))

    assert_no_changes -> { writes } do
      assert_equal :card_not_showcased, place(@cards[3], 0).failure
    end
  end

  test "a visitor, a banned or a deleted player is refused" do
    showcase(@cards.first(2))

    assert_no_changes -> { writes } do
      assert_equal :player_required, place(@cards[0], 1, player: nil).failure
      assert_equal :player_required, place(@cards[0], 1, player: accounts_players(:banned)).failure
      @player.update!(deleted_at: Time.current, steam_id: nil)
      assert_equal :player_required, place(@cards[0], 1).failure
    end
  end

  test "a gap or a shared place is read in order of place then id, and the drop renumbers 0..n-1" do
    showcase(@cards.first(4))
    entries = Game::ShowcaseEntry.where(player_id: @player.id)
    entries.where(card_season_id: @cards[1]).update_all(position: 3)
    entries.where(card_season_id: @cards[2]).update_all(position: 3)
    entries.where(card_season_id: @cards[3]).update_all(position: 4)

    place(@cards[0], 3).value!

    assert_equal [ [ @cards[1], 0 ], [ @cards[2], 1 ], [ @cards[3], 2 ], [ @cards[0], 3 ] ], places
  end
end
