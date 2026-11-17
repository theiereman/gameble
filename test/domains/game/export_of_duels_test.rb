require "test_helper"
require_relative "../../support/live_duels"

# The data export lists a player's finished duels with their date, score, result and rounds, and never the opponent.
class Game::ExportOfDuelsTest < ActiveSupport::TestCase
  include LiveDuels

  setup do
    @lea = accounts_players(:player)
    @hugo = accounts_players(:moderator)
    @lea.update!(persona_name: "Léa")
    @hugo.update!(persona_name: "Hugo")
    befriend(@lea, @hugo)
    complete_deck(@lea, "Lea")
    complete_deck(@hugo, "Hugo")
  end

  def finish(duel) = 10.times.reduce(duel) { |played, _| play_round(played) }

  def export(player) = PlayerExport.new(Accounts::Player.find(player.id), locale: :en)

  test "a player with no duel has an empty list, and a duel still in progress or a challenge is not in it" do
    start_duel(@lea, @hugo)

    assert_empty Game::ExportOf.call(@lea).duels
    assert_equal [], export(@lea).to_h[:duels]
  end

  test "each finished duel is listed from the player's side, with its rounds, in the order they ended" do
    finished = finish(start_duel(@lea, @hugo))

    mine = Game::ExportOf.call(@lea).duels.sole
    theirs = Game::ExportOf.call(@hugo).duels.sole

    assert_equal [ finished.ended_at, finished.challenger_score, finished.opponent_score ], [ mine.ended_at, mine.score, mine.opponent_score ]
    assert_equal [ finished.opponent_score, finished.challenger_score ], [ theirs.score, theirs.opponent_score ]
    assert_equal({ "challenger" => %w[win loss], "opponent" => %w[loss win], "draw" => %w[draw draw] }.fetch(finished.result), [ mine.result, theirs.result ])
    assert_equal (1..10).to_a, mine.rounds.map(&:number)
    assert_equal mine.rounds.map(&:called), theirs.rounds.map { !it.called }
    assert_equal mine.rounds.map(&:value), theirs.rounds.map(&:opponent_value)
    assert_equal 20, mine.card_season_ids.size
  end

  test "the exported duels name nobody: not the opponent, banned or deleted, and carry no database id or token" do
    finished = finish(start_duel(@lea, @hugo))
    Accounts::DeletePlayer.new.call(player: Accounts::Player.find(@hugo.id)).value!

    json = export(@lea).to_h.fetch(:duels).to_json
    duel = export(@lea).to_h.fetch(:duels).sole

    assert_equal %i[endedAt score opponentScore result rounds], duel.keys
    assert_equal %i[number calledByYou card opponentCard stat direction value opponentValue outcome playedAutomatically opponentPlayedAutomatically],
      duel[:rounds].first.keys
    [ "Hugo", @hugo.token, @hugo.steam_id, finished.token ].compact.each { assert_not_includes json, it }
    assert_equal [ nil ], [ Game::DuelSeat.find_by!(duel_id: finished.id, role: "opponent").player_id ]
  end

  test "a banned opponent is not named either" do
    finished = finish(start_duel(@lea, @hugo))
    Accounts::BanPlayer.new.call(staff: accounts_players(:administrator), player: @hugo, reason: "Cheating").value!

    json = export(@lea).to_h.fetch(:duels).to_json

    [ "Hugo", @hugo.token, finished.token ].each { assert_not_includes json, it }
    assert_equal 10, JSON.parse(json).sole.fetch("rounds").size
  end
end
