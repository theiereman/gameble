require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/live_duels"

# Giving up an active duel: the opponent wins it, no capsule is granted, and the seats are free again.
class Game::ForfeitDuelTest < ActiveSupport::TestCase
  include GamePacks
  include LiveDuels

  setup do
    @lea = accounts_players(:player)
    @hugo = accounts_players(:moderator)
    befriend(@lea, @hugo)
    complete_deck(@lea, "Lea")
    complete_deck(@hugo, "Hugo")
    @duel = start_duel(@lea, @hugo)
  end

  def current = Game::Duel.find(@duel.id)

  def forfeit(player, token: @duel.token) = Game::ForfeitDuel.new.call(player:, token:)

  test "the player who gives up loses: the duel finishes in favour of the other seat, without a capsule" do
    forfeit(@lea).value!

    duel = current
    assert_equal [ "finished", "opponent", "challenger", nil ], [ duel.state, duel.result, duel.forfeited_by, duel.capsule ]
    assert duel.ended_at
    assert_equal %w[left left], duel.seats.map(&:status)
    assert_kind_of Game::DuelFinished, Rails.configuration.event_store.read.of_type([ Game::DuelFinished ]).last
  end

  test "the seat that gives up is read from its own seat, the challenger or the opponent" do
    forfeit(@hugo).value!

    assert_equal [ "challenger", "opponent" ], [ current.result, current.forfeited_by ]
  end

  test "a duel already finished, or a duel of someone else, is refused and writes nothing" do
    forfeit(@lea).value!
    before = current.attributes

    assert_equal :not_your_move, forfeit(@hugo).failure
    assert_equal :duel_not_found, forfeit(accounts_players(:administrator)).failure
    assert_equal before, current.attributes
  end

  test "the duel is no longer in progress for either player, who can challenge again" do
    forfeit(@lea).value!

    assert_not Game::DuelSeat.exists?(player_id: [ @lea.id, @hugo.id ], status: %w[seated invited])
  end

  test "the screen reads the other seat as the winner, whatever the score, and says who gave up" do
    forfeit(@lea).value!
    duel = current

    screen = DuelScreen.new(duel, duel.seat_of(@hugo), locale: :en)

    assert_equal [ :win, true, false ], [ screen.outcome, screen.forfeited?, screen.forfeited_by_me? ]
    assert_not screen.decided_on_margin?
  end
end
