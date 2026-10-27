require "test_helper"

# A pack's row (epic 3 retrospective, D1 and O2): Game::Pack.row, the one
# shape of a new pack, and the database's check on its cards: one dimension,
# at least one card-season id and no NULL, five for a regular pack and three
# for a daily bonus pack.
class Game::PackTest < ActiveSupport::TestCase
  setup do
    @player_id = accounts_players(:player).id
    @season_id = catalog_seasons(:one).id
    @card = catalog_card_seasons(:portal_one).id
  end

  def row(kind, cards)
    Game::Pack.row(player_id: @player_id, kind:, season_id: @season_id, card_season_ids: cards, available_at: Time.current)
  end

  def insert(kind, cards)
    Game::Pack.insert_all!([ row(kind, cards) ])
  end

  test "a row carries the pack's attributes, its kind as a string and a fresh token" do
    now = Time.current
    first = Game::Pack.row(player_id: @player_id, kind: :bonus, season_id: @season_id, card_season_ids: [ @card ] * 3, available_at: now)
    second = row(:bonus, [ @card ] * 3)

    assert_equal({ player_id: @player_id, kind: "bonus", season_id: @season_id, card_season_ids: [ @card ] * 3, available_at: now },
      first.except(:token))
    assert_match(/\A[0-9a-zA-Z]{24}\z/, first[:token])
    assert_not_equal first[:token], second[:token]
  end

  test "the database stores a regular pack of five, a bonus pack of three and a reward pack of one or more" do
    insert(:regular, [ @card ] * 5)
    insert(:bonus, [ @card ] * 3)
    insert(:reward, [ @card ])
    insert(:reward, [ @card ] * 7)

    assert_equal [ 1, 3, 5, 7 ], Game::Pack.where(player_id: @player_id).map { it.card_season_ids.size }.sort
  end

  test "the database refuses a pack whose cards are malformed" do
    {
      "a regular pack of four" => [ :regular, [ @card ] * 4 ],
      "a regular pack of six" => [ :regular, [ @card ] * 6 ],
      "a bonus pack of five" => [ :bonus, [ @card ] * 5 ],
      "an empty reward pack" => [ :reward, [] ],
      "a NULL card-season id" => [ :reward, [ @card, nil ] ],
      "a two-dimensional list" => [ :reward, [ [ @card, @card ], [ @card, @card ] ] ]
    }.each do |name, (kind, cards)|
      error = assert_raises(ActiveRecord::StatementInvalid, name) { Game::Pack.transaction(requires_new: true) { insert(kind, cards) } }
      assert_match(/game_packs_card_season_ids_check/, error.message, name)
    end

    assert_equal 0, Game::Pack.where(player_id: @player_id).count
  end
end
