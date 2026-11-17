require "test_helper"

class DuelsHelperTest < ActionView::TestCase
  include DuelsHelper
  include DuelProfileHelper

  Screen = Struct.new(:outcome, :score, :other_score, :margin_gap, :opponent) do
    def decided_on_margin? = score == other_score && outcome != :draw
  end

  Friend = Struct.new(:persona_name) do
    def removed? = false
  end

  def screen(outcome, score, other_score, margin_gap = 0) = Screen.new(outcome, score, other_score, margin_gap, Friend.new("Hugo"))

  test "a margin is spoken as plus or minus its points, and as the plain number when level" do
    assert_equal "plus 3", duel_margin_spoken(BigDecimal("3"))
    assert_equal "minus 2.5", duel_margin_spoken(BigDecimal("-2.5"))
    assert_equal "0", duel_margin_spoken(BigDecimal("0"))
  end

  test "the result is spoken with the score, and the margin that decided equal scores" do
    assert_equal "Win against Hugo, 6 to 4", duel_result_spoken(screen(:win, 6, 4, 8))
    assert_equal "Draw with Hugo, 5 to 5", duel_result_spoken(screen(:draw, 5, 5))
    assert_equal "Loss against Hugo, 5 to 5, decided on the margin of 12 percentile points", duel_result_spoken(screen(:loss, 5, 5, BigDecimal("-12")))
    I18n.with_locale(:fr) do
      assert_equal "Victoire contre Hugo, 5 à 5, départagée à l'écart de 12 points de centile", duel_result_spoken(screen(:win, 5, 5, BigDecimal("12")))
    end
  end

  test "a banned or deleted opponent, or none, reads anonymous in the result, the bell line and the closing notices" do
    removed = [ nil, Accounts::Player.new(persona_name: "Hugo", banned_at: Time.current), Accounts::Player.new(deleted_at: Time.current) ]
    anonymous = I18n.t("player_name.anonymous")

    removed.each do |opponent|
      assert_equal "Win against #{anonymous}, 6 to 4", duel_result_spoken(Screen.new(:win, 6, 4, 8, opponent))
      assert_not_includes duel_plain_name(opponent), "Hugo"
      assert_includes render(partial: "duels/sheet_outcome", locals: { outcome: DuelUpdate::Outcome.new(kind: "lapsed", other: opponent, token: "t") }), anonymous
      assert_includes ApplicationController.render(partial: "player_streams/update", formats: [ :turbo_stream ], locals: update_locals(opponent)), anonymous
    end
  end

  def update_locals(opponent)
    closing = DuelUpdate::Closing.new(kind: "cancelled", other: opponent)
    { waiting: nil, invitations: nil, friends: [], unclaimed: nil, balance: nil, outbid: nil, duels_active: nil, pending: nil, achievements: [],
      card_backs: [], duel: Struct.new(:closings, :outcome) { def received? = false }.new([ closing ], nil), signals: [], outbid_lines: [],
      player: accounts_players(:player) }
  end

  test "a direction in a sentence keeps its capital in English and takes a small letter in French" do
    assert_equal "Oldest", duel_direction_inline(:release, :low)
    I18n.with_locale(:fr) { assert_equal "la plus ancienne", duel_direction_inline(:release, :low) }
  end
end
