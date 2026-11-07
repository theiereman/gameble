require "test_helper"
require_relative "../../support/catalog_seeds"
require_relative "../../support/game_packs"

# Game::HeldPacks: the capsule an opening of each reserve takes next, as
# long as it was drawn in the published season; and Game::FirstCopies
# before that opening.
class Game::HeldPacksTest < ActiveSupport::TestCase
  include CatalogSeeds
  include GamePacks

  setup { @player = accounts_players(:player) }

  def held = Game::HeldPacks.call(@player)

  test "each reserve holds its oldest available capsule, the one an opening of it takes" do
    standard = create_pack(@player, available_at: 3.minutes.ago)
    create_pack(@player, available_at: 1.minute.ago)
    special = create_pack(@player, kind: :reward, available_at: 2.minutes.ago)
    create_pack(@player, kind: :bonus, available_at: 1.minute.ago)
    create_pack(@player, available_at: 1.hour.from_now)

    assert_equal({ "standard" => standard, "special" => special }, held)
    assert_equal special, Game::OpenPack.new.call(player: @player, reserve: "special").value!
    assert_equal standard, Game::OpenPack.new.call(player: @player, reserve: "standard").value!
  end

  test "an empty reserve, a capsule not yet available or another player's holds nothing" do
    create_pack(@player, available_at: 1.hour.from_now)
    create_pack(@player, kind: :bonus, opened_at: 1.minute.ago)
    create_pack(accounts_players(:moderator), available_at: 1.minute.ago)

    assert_equal({ "standard" => nil, "special" => nil }, held)
    assert_equal({ "standard" => nil, "special" => nil }, Game::HeldPacks.call(nil))
  end

  test "a capsule drawn in an earlier season, or with no season published, is held by no reserve: opening would redraw it" do
    create_pack(@player)
    create_pack(@player, kind: :bonus, cards: fixture_tier_ids.last(3))

    without_published_season { assert_equal({ "standard" => nil, "special" => nil }, held) }

    season = seed_card_seasons(distinct_scores(150))
    Catalog::PublishSeason.new.call(number: season.number).value!
    assert_equal({ "standard" => nil, "special" => nil }, held)
  end

  test "after an opening, the next held capsule of the same reserve" do
    opened = create_pack(@player, kind: :bonus, available_at: 3.minutes.ago)
    following = create_pack(@player, kind: :reward, available_at: 2.minutes.ago)
    create_pack(@player, available_at: 4.minutes.ago)

    Game::OpenPack.new.call(player: @player, reserve: "special").value!

    assert_equal following, Game::HeldPacks.after(@player, opened)
    Game::OpenPack.new.call(player: @player, reserve: "special").value!
    assert_nil Game::HeldPacks.after(@player, following)
  end

  test "before opening, a first copy is a card the player never held, once even when drawn twice, as the opening will say" do
    common, portal, rare = %i[common_card_one portal_one rare_card_one].map { catalog_card_seasons(it).id }
    Game::Holding.create!(player_id: @player.id, card_season_id: portal, quantity: 1)
    Game::Holding.create!(player_id: @player.id, card_season_id: rare, quantity: 0)
    pack = create_pack(@player, cards: [ common, portal, common, rare, portal ])

    assert_equal [ true, false, false, false, false ], Game::FirstCopies.before_opening(@player, pack)
    assert_equal [ false ] * 5, Game::FirstCopies.before_opening(nil, pack)
  end
end
