require "test_helper"

class Game::Market::CardNamesTest < ActiveSupport::TestCase
  setup { @common = catalog_card_seasons(:common_card_one) }

  test "it names a card-season with its title and season number" do
    name = Game::Market::CardNames.call([ @common.id ], locale: :en).fetch(@common.id)

    assert_equal "Tin Soldier", name.title
    assert_equal @common.season.number, name.season_number
  end

  test "it uses the title of the locale" do
    assert_equal "Soldat de plomb", Game::Market::CardNames.call([ @common.id ], locale: :fr).fetch(@common.id).title
  end

  test "it falls back to the English title when the locale has none" do
    Catalog::CardText.where(card_id: @common.card_id, locale: "fr").delete_all

    assert_equal "Tin Soldier", Game::Market::CardNames.call([ @common.id ], locale: :fr).fetch(@common.id).title
  end

  test "no id gives no name" do
    assert_equal({}, Game::Market::CardNames.call([]))
  end
end
