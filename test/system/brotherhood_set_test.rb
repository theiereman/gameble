require "application_system_test_case"
require_relative "../support/catalog_seeds"
require_relative "../support/game_sets"

# A set judged by the Brotherhood, open to a visitor: its filters narrow it
# under an unchanged header, and a card opened from it leads back to it.
class BrotherhoodSetTest < ApplicationSystemTestCase
  include CatalogSeeds
  include GameSets

  test "a visitor narrows a Brotherhood set to its cards to discover, clears it, and opens a found card whose back leads to the set" do
    season, cards = published_cards(6)
    insert_theme(cards, key: "roguelike", season:)
    Game::FirstDiscovery.delete_all
    lea = accounts_players(:player)
    lea.update_columns(persona_name: "Léa", visibility: "public")
    Game::FirstDiscovery.create!(card_season_id: cards.first, player_id: lea.id, discovered_at: 1.hour.ago)
    set_path = brotherhood_set_path(locale: :en, kind: "theme", key: "roguelike")

    visit set_path
    assert_selector "#set-album-heading:focus"
    assert_selector ".brotherhood-set__grid > li", count: 6, visible: :all
    assert_selector ".brotherhood-card__pioneer a", text: "Léa", visible: :all
    header = find(".set-album__header").text

    find(".filters__summary").click
    find(".filter-chip__text", text: /\ATo discover\z/i).click
    assert_selector ".brotherhood-set__grid > li", count: 5, visible: :all
    assert_no_selector ".brotherhood-set__grid .card:not(.card--not-owned)", visible: :all
    assert_selector "[data-group=state] .filter-chip__box[value=undiscovered]:focus", visible: :all
    assert_equal header, find(".set-album__header").text

    find(".filters__clear").click
    assert_selector ".brotherhood-set__grid > li", count: 6, visible: :all

    find(".brotherhood-set__grid > li:first-child a.card-link").click
    assert_selector "a.top-bar__phone-back[href='#{set_path}']", text: /Great Inventory/i, visible: :all
  end
end
