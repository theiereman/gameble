require "test_helper"
require_relative "../../support/catalog_seeds"

# Game::SetProgress: per set, the members whose game a player holds, in any
# edition.
class Game::SetProgressTest < ActiveSupport::TestCase
  include CatalogSeeds

  setup do
    @season = publish_sets_draft
    @sets = Catalog::Set.where(season_id: @season.id).index_by(&:key)
    @player = accounts_players(:player)
  end

  def members(key)
    Catalog::SetMembership.where(set_id: @sets.fetch(key).id).order(:position).pluck(:card_season_id)
  end

  def hold(player, card_season_id, quantity)
    Game::Holding.create!(player_id: player.id, card_season_id:, quantity:)
  end

  def progress(player, *keys)
    Game::SetProgress.call(player, @sets.values_at(*keys).map(&:id)).transform_keys { |id| @sets.values.find { |set| set.id == id }.key }
  end

  test "a player owning 3 of a theme's cards, one twice, has 3 of it" do
    first, second, third = members("horror").first(3)
    hold(@player, first, 1)
    hold(@player, second, 2)
    hold(@player, third, 1)

    assert_equal({ "horror" => 3 }, progress(@player, "horror", "ufos"))
  end

  test "a card in two themes counts in both" do
    card = members("pirates").first
    hold(@player, card, 1)

    assert_equal({ "pirates" => 1, "horror" => 1 }, progress(@player, "pirates", "horror", "rpg"))
  end

  test "a holding at 0 is not counted" do
    hold(@player, members("rpg").first, 0)

    assert_equal({}, progress(@player, "rpg"))
  end

  test "another player's cards are theirs, and only the sets asked about are answered" do
    hold(accounts_players(:moderator), members("rpg").first, 1)
    hold(@player, members("rpg").last, 1)

    assert_equal({ "rpg" => 1 }, progress(accounts_players(:moderator), "rpg"))
    assert_equal({ "rpg" => 1 }, progress(@player, "rpg", "ufos"))
    assert_equal({}, progress(@player, "ufos", "pirates"))
  end

  test "a game held only in an earlier edition counts in the published season's set, once" do
    card = Catalog::CardSeason.find(members("pirates").first)
    later = Catalog::Season.create!(status: :draft, number: Catalog::Season.next_number)
    Catalog::CardSeason.insert_all!([ { card_id: card.card_id, season_id: later.id, prestige_score: 1, rating: 80 } ])
    hold(@player, Catalog::CardSeason.find_by!(card_id: card.card_id, season_id: later.id).id, 1)
    hold(@player, card.id, 2)

    assert_equal({ "pirates" => 1, "horror" => 1 }, progress(@player, "pirates", "horror"))
  end

  test "one query for a player, none for a visitor or no set" do
    hold(@player, members("pirates").first, 1)
    ids = @sets.values.map(&:id)

    assert_queries_count(1) { Game::SetProgress.call(@player, ids) }
    assert_queries_count(0) { assert_equal({}, Game::SetProgress.call(nil, ids)) }
    assert_queries_count(0) { assert_equal({}, Game::SetProgress.call(@player, [])) }
  end
end
