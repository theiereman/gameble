require "test_helper"

class Game::Market::WantedTest < ActiveSupport::TestCase
  def insert(reason:, rarities:)
    Game::Market::Wanted.insert_all([ { player_id: accounts_players(:player).id, card_id: catalog_cards(:common_card).id, reason:, rarities: } ])
  end

  test "a goal row carries no rarities and an order row some" do
    insert(reason: "goal", rarities: nil)
    insert(reason: "order", rarities: [ 1, 2 ])

    assert_equal [ [ "goal", nil ], [ "order", [ 1, 2 ] ] ], Game::Market::Wanted.order(:reason).pluck(:reason, :rarities)
  end

  test "the table refuses an unknown reason, a goal with rarities and an order without" do
    [ [ "wish", nil ], [ "goal", [ 1 ] ], [ "order", nil ] ].each do |reason, rarities|
      assert_raises(ActiveRecord::CheckViolation) { Game::Market::Wanted.transaction(requires_new: true) { insert(reason:, rarities:) } }
    end
  end
end
