require "test_helper"

class SocialHelperTest < ActionView::TestCase
  View = Data.define(:rarity)

  def row(state, card_season_ids = [])
    lines = card_season_ids.map { Game::TradesOf::Line.new(card_season_id: it, quantity: 1) }
    Game::TradesOf::Row.new(id: 1, token: "trade-token", friend: nil, friend_title: nil, own_title: nil, state:, outcome: nil,
      friend_side: lines, own_side: [], expires_at: nil, ended_at: nil, revision: 1)
  end

  test "the highest rarity is the top tier among the trade's resolvable cards" do
    cards = { 1 => View.new("common"), 2 => View.new("epic"), 3 => View.new("rare") }

    assert_equal "epic", trade_top_rarity(row(:yours, [ 1, 2, 3 ]), cards)
    assert_equal "common", trade_top_rarity(row(:yours, [ 1, 9 ]), cards)
  end

  test "a trade with no resolvable card has no rarity" do
    assert_nil trade_top_rarity(row(:theirs, [ 9 ]), {})
    assert_nil trade_top_rarity(row(:theirs), {})
  end

  test "an open trade reads whose turn it is; an ended one a muted outcome" do
    I18n.with_locale(:fr) do
      assert_equal [ "alert", "À vous" ], social_trade_chip(row(:yours))
      assert_equal [ "accent", "À son tour" ], social_trade_chip(row(:theirs))
    end
    I18n.with_locale(:en) do
      assert_equal [ "muted", "Done" ], social_trade_chip(row(:concluded))
      assert_equal [ "muted", "Closed" ], social_trade_chip(row(:closed))
    end
  end
end
