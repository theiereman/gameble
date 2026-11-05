require "test_helper"
require_relative "../../support/holdings"

# Game::FriendsOwning: the viewer's visible friends who own a game, those
# holding the edition viewed first, the others with the editions they hold.
class Game::FriendsOwningTest < ActiveSupport::TestCase
  include Holdings

  setup do
    @viewer = accounts_players(:player)
    @portal = catalog_card_seasons(:portal_one)
  end

  def befriend(name, visibility: :public)
    friend = Accounts::Player.create!(steam_id: "765611980000#{(Accounts::Player.count + 1).to_s.rjust(5, "0")}", persona_name: name, visibility:)
    low, high = [ @viewer.id, friend.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
    friend
  end

  def edition(number, rarity:)
    season = Catalog::Season.create!(status: :published, number:, published_at: Time.current)
    Catalog::CardSeason.insert_all!([ { card_id: @portal.card_id, season_id: season.id, prestige_score: 0.5, rating: 90, rarity:, number: 1 } ],
      returning: :id).rows.flatten.sole
  end

  def owners = Game::FriendsOwning.call(@viewer, card_id: @portal.card_id, card_season_id: @portal.id)

  def lines(owners) = owners.map { [ it.player.persona_name, it.copies, it.editions ] }

  test "a friend holding the viewed edition comes first with its copies; one holding only another edition comes after with their editions" do
    sam = befriend("Sam")
    ada = befriend("Ada")
    hold(sam, @portal.id, 2)
    hold(ada, edition(2, rarity: "rare"), 1)

    result = nil
    assert_queries_count(3) { result = owners }
    assert_equal [ [ "Sam", 2, [ [ "epic", 1, 2 ] ] ] ], lines(result.same)
    assert_equal [ [ "Ada", 1, [ [ "rare", 2, 1 ] ] ] ], lines(result.other)
    assert_not result.none?
  end

  test "a friend holding the viewed and another edition is only in the first section, counting the viewed edition's copies" do
    sam = befriend("Sam")
    hold(sam, @portal.id, 1)
    hold(sam, edition(2, rarity: "legendary"), 3)

    assert_equal [ [ "Sam", 1, [ [ "legendary", 2, 3 ], [ "epic", 1, 1 ] ] ] ], lines(owners.same)
    assert_empty owners.other
  end

  test "the other section counts every edition held, by copies then name" do
    zoe = befriend("Zoe")
    bob = befriend("bob")
    cid = befriend("Cid")
    s2 = edition(2, rarity: "rare")
    s3 = edition(3, rarity: "common")
    hold(zoe, s2, 1)
    hold(zoe, s3, 2)
    hold(bob, s2, 1)
    hold(cid, s3, 1)

    assert_equal [ [ "Zoe", 3 ], [ "bob", 1 ], [ "Cid", 1 ] ], owners.other.map { [ it.player.persona_name, it.copies ] }
  end

  test "a private friend, a stranger and a holding of no copies are never owners" do
    hold(befriend("Hidden", visibility: :private), @portal.id, 1)
    hold(accounts_players(:moderator), @portal.id, 1)
    hold(befriend("Empty"), @portal.id, 0)

    assert owners.none?
    assert_equal [ [], [] ], [ owners.same, owners.other ]
  end

  test "a friends-only friend is an owner; a banned friend is not" do
    hold(befriend("Close", visibility: :friends_only), @portal.id, 1)
    banned = accounts_players(:banned)
    low, high = [ @viewer.id, banned.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
    hold(banned, @portal.id, 1)

    assert_equal [ "Close" ], owners.same.map { it.player.persona_name }
  end

  test "no friends, or no viewer: none, without a query for a visitor" do
    assert owners.none?
    assert_queries_count(0) { assert Game::FriendsOwning.call(nil, card_id: @portal.card_id, card_season_id: @portal.id).none? }
  end
end
