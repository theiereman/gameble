require "test_helper"
require_relative "../../support/game_packs"

# Game::FirstCopies: which cards of an opened pack the player received for
# the first time, in the pack's drawn order.
class Game::FirstCopiesTest < ActiveSupport::TestCase
  include GamePacks

  setup do
    @player = accounts_players(:player)
    @common, @portal, @rare = %i[common_card_one portal_one rare_card_one].map { catalog_card_seasons(it).id }
  end

  test "a card first held by this opening is a first copy, once even when drawn twice; a card held before is not" do
    Game::Holding.create!(player_id: @player.id, card_season_id: @portal, quantity: 1)
    create_pack(@player, cards: [ @common, @portal, @common, @rare, @portal ])

    pack = Game::OpenPack.new.call(player: @player).value!

    assert_equal [ true, false, false, true, false ], pack_first_copies(pack)
  end

  test "an earlier pack's first copies are no longer first in a later one" do
    create_pack(@player, cards: [ @common ] * 5, available_at: 2.minutes.ago)
    create_pack(@player, cards: [ @common, @rare, @rare, @rare, @rare ])

    first = Game::OpenPack.new.call(player: @player).value!
    second = Game::OpenPack.new.call(player: @player).value!

    assert_equal [ true, false, false, false, false ], pack_first_copies(first)
    assert_equal [ false, true, false, false, false ], pack_first_copies(second)
  end

  test "none for a visitor or an unopened pack" do
    pack = create_pack(@player, cards: [ @common ] * 5)

    assert_equal [ false ] * 5, Game::FirstCopies.call(nil, pack)
    assert_equal [ false ] * 5, Game::FirstCopies.call(@player, pack)
  end

  private

  def pack_first_copies(pack)
    Game::FirstCopies.call(@player, pack.reload)
  end
end
