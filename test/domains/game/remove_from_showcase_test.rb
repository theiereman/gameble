require "test_helper"
require_relative "../../support/game_packs"

# Taking a card out of the player's profile showcase: the later cards move
# up one place.
class Game::RemoveFromShowcaseTest < ActiveSupport::TestCase
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

  def remove(card_season_id, player: @player)
    Game::RemoveFromShowcase.new.call(player:, card_season_id:)
  end

  def writes = Game::ShowcaseEntry.count + Rails.configuration.event_store.read.count

  test "a card leaves the showcase, the later ones move up, with one event" do
    showcase(@cards.first(4))

    result = remove(@cards[1])

    assert result.success?
    assert_equal [ [ @cards[0], 0 ], [ @cards[2], 1 ], [ @cards[3], 2 ] ],
      Game::ShowcaseEntry.where(player_id: @player.id).order(:position).pluck(:card_season_id, :position)
    event = game_events(@player, Game::ShowcaseCardRemoved).sole
    assert_equal({ player_id: @player.id, card_season_id: @cards[1] }, event.data)
  end

  test "a card added after a removal joins at the end" do
    showcase(@cards.first(3))
    remove(@cards[0]).value!

    showcase([ @cards[3] ])

    assert_equal @cards[1..3], Game::ChosenShowcase.call(@player)
    assert_equal [ 0, 1, 2 ], Game::ShowcaseEntry.where(player_id: @player.id).order(:position).pluck(:position)
  end

  test "a removal renumbers the remaining cards from the rows as they stand, a gap or a shared place included" do
    showcase(@cards.first(4))
    entries = Game::ShowcaseEntry.where(player_id: @player.id)
    entries.where(card_season_id: @cards[1]).update_all(position: 3)
    entries.where(card_season_id: @cards[2]).update_all(position: 3)
    entries.where(card_season_id: @cards[3]).update_all(position: 4)

    remove(@cards[0]).value!

    ids = entries.where(card_season_id: [ @cards[1], @cards[2] ]).order(:id).pluck(:card_season_id)
    assert_equal [ [ ids[0], 0 ], [ ids[1], 1 ], [ @cards[3], 2 ] ], entries.order(:position).pluck(:card_season_id, :position)
    assert_equal [ *ids, @cards[3] ], Game::ChosenShowcase.call(@player)
  end

  test "a card not in the showcase is refused" do
    showcase([ @cards[0] ])

    assert_no_difference -> { writes } do
      assert_equal :card_not_showcased, remove(@cards[1]).failure
    end
  end

  test "a visitor, a banned or a deleted player is refused" do
    showcase([ @cards[0] ])

    assert_no_difference -> { writes } do
      assert_equal :player_required, remove(@cards[0], player: nil).failure
      assert_equal :player_required, remove(@cards[0], player: accounts_players(:banned)).failure
      @player.update!(deleted_at: Time.current, steam_id: nil)
      assert_equal :player_required, remove(@cards[0]).failure
    end
  end
end
