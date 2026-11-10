require "test_helper"

class BellHelperTest < ActionView::TestCase
  def subject_of(card: nil, partner_card: nil, set: nil)
    bell_reaction_subject(Game::BellItems::ReactionSubject.new(card:, partner_card:, set:))
  end

  def market_notice(kind: :outbid, other: accounts_players(:administrator), amount: 30_000, at: Time.utc(2026, 11, 10, 12, 0, 0))
    Game::Market::MarketNotices::Line.new(kind:, token: "tok", card: "Portal", other:, amount:, noticed_at: at)
  end

  test "a reaction line names the card, both cards of a trade, or the set the entry shows, in both languages" do
    assert_equal "Portal", subject_of(card: "Portal")
    assert_equal "Valve", subject_of(set: catalog_sets(:valve_one))
    assert_equal "Portal for Hades", subject_of(card: "Portal", partner_card: "Hades")
    I18n.with_locale(:fr) { assert_equal "Portal contre Hades", subject_of(card: "Portal", partner_card: "Hades") }
  end

  test "a reaction line whose card left the catalog names nothing" do
    assert_nil subject_of
  end

  test "an outbid line names the other player without a link, leads to the Annonce and clears with its target" do
    accounts_players(:administrator).update_columns(persona_name: "Max")

    line = bell_market_line(market_notice)

    assert_equal market_listing_path(token: "tok"), line.path
    assert_equal line.path, line.href
    assert_equal "market:tok:2026-11-10T12:00:00.000000Z", line.key
    assert_includes line.sentence, "Max"
    assert_includes line.sentence, "went past your maximum on Portal."
    assert_not_includes line.sentence, "<a"
    assert_not line.lasting
  end

  test "an outbid line reads in French" do
    accounts_players(:administrator).update_columns(persona_name: "Max")

    I18n.with_locale(:fr) { assert_includes bell_market_line(market_notice).sentence, "a dépassé votre maximum sur Portal." }
  end

  test "a removed player is named anonymously" do
    removed = accounts_players(:administrator)
    removed.update_columns(deleted_at: Time.current)

    assert_includes bell_market_line(market_notice(other: removed)).sentence, I18n.t("player_name.anonymous")
  end

  test "a market line comes after the reaction lines and before the daily capsule" do
    items = Game::BellItems::Result.new(trades: [], updates: [], invitations: [], reactions: [], market: [ market_notice ], daily: nil,
      goal: Game::BellItems::GoalLine.new(week_start: Date.new(2026, 11, 9), reward_ready: false, target: 10, reached: false))

    assert_equal [ "market", "mission" ], bell_lines(items).map { it.key.split(":").first }
  end
end
