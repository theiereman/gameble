require "test_helper"

class SocialHelperTest < ActionView::TestCase
  View = Data.define(:rarity)

  def row(state, card_season_ids = [])
    lines = card_season_ids.map { Game::TradesOf::Line.new(card_season_id: it, quantity: 1) }
    Game::TradesOf::Row.new(id: 1, token: "trade-token", friend: nil, friend_title: nil, own_title: nil, state:, outcome: nil,
      friend_side: lines, own_side: [], expires_at: nil, ended_at: nil, revision: 1)
  end

  test "a side counts every copy and lists its pips from the highest rarity down" do
    cards = { 1 => View.new("common"), 2 => View.new("epic"), 3 => View.new("rare") }
    lines = [ 1, 2, 3 ].map { Game::TradesOf::Line.new(card_season_id: it, quantity: it == 1 ? 2 : 1) }

    side = trade_side(lines, cards)

    assert_equal 4, side.count
    assert_equal %w[epic rare common common], side.pips
    assert_equal 0, side.overflow
    assert_equal "epic", side.best
  end

  test "a side past six cards shows six pips and the overflow" do
    cards = { 1 => View.new("rare") }
    side = trade_side([ Game::TradesOf::Line.new(card_season_id: 1, quantity: 9) ], cards)

    assert_equal 6, side.pips.size
    assert_equal 3, side.overflow
  end

  test "an empty side has no pip and no best rarity" do
    side = trade_side([], {})

    assert_equal [ 0, [], 0, nil ], [ side.count, side.pips, side.overflow, side.best ]
  end

  test "an open trade reads whose turn it is" do
    I18n.with_locale(:fr) do
      assert_equal [ "alert", "À vous" ], social_trade_chip(row(:yours))
      assert_equal [ "accent", "À son tour" ], social_trade_chip(row(:theirs))
    end
  end

  test "the hidden names read up to three, then and n others" do
    I18n.with_locale(:fr) do
      assert_equal "Sam", names_and_others(%w[Sam])
      assert_equal "Sam et Zoé", names_and_others(%w[Sam Zoé])
      assert_equal "Sam, Zoé et Hugo", names_and_others(%w[Sam Zoé Hugo])
      assert_equal "Sam, Zoé, Hugo et 1 autre", names_and_others(%w[Sam Zoé Hugo Léa])
      assert_equal "Sam, Zoé, Hugo et 2 autres", names_and_others(%w[Sam Zoé Hugo Léa Max])
    end
    I18n.with_locale(:en) { assert_equal "Sam, Zoé, Hugo and 2 others", names_and_others(%w[Sam Zoé Hugo Léa Max]) }
  end

  test "the line for the rest reads the player's turn when any hidden trade waits on them" do
    I18n.with_locale(:en) do
      assert_equal [ "alert", "Your turn" ], social_others_chip([ row(:theirs), row(:yours) ])
      assert_equal [ "accent", "Their turn" ], social_others_chip([ row(:theirs), row(:theirs) ])
    end
  end
end
