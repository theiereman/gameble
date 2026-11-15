require "application_system_test_case"
require_relative "../support/catalog_seeds"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

# The Monday duel stats run posts to the whole feed the cards whose standing moved most since the deploy's first run;
# Friends and the hub's ticker never show it.
class DuelStatsFeedTest < ApplicationSystemTestCase
  include CatalogSeeds
  include GamePacks
  include SteamSignIn

  setup do
    season = seed_card_seasons(distinct_scores(8), review_counts: (1..8).map { it * 10 })
    season.update!(status: :published, published_at: 1.day.ago)
    @ids = Catalog::CardSeason.where(season_id: season.id).order(:id).ids
    @ids.each_with_index { |id, index| Catalog::CardSeason.where(id:).update_all(rarity: 1, number: index + 1) }
    @season_number = season.number
    Game::ComputeDuelStats.new.call(reason: "first").value!
    @ids.each_with_index { |id, index| Catalog::CardSeason.where(id:).update_all(review_count: (8 - index) * 10) }
    Game::ComputeDuelStats.new.call(reason: "weekly").value!
  end

  def edition_path(index) = card_season_path(locale: :fr, slug: "seed-#{@season_number}-#{index}", number: @season_number)

  test "a visitor reads the three largest rises and falls under Tous, each card linked to its edition; Amis and the ticker never show it" do
    visit feed_path(locale: :fr)

    within ".feed__entry--duel-stats" do
      assert_selector ".feed__headline-title", text: "Le cours des cartes a bougé."
      assert_equal [ "Seed 0, popularité en hausse, de 6 à 94", "Seed 1, popularité en hausse, de 19 à 81", "Seed 2, popularité en hausse, de 31 à 69",
        "Seed 7, popularité en baisse, de 94 à 6", "Seed 6, popularité en baisse, de 81 à 19", "Seed 5, popularité en baisse, de 69 à 31" ],
        all(".feed__move", count: 6).map(&:text)
      assert_link "Seed 0", href: edition_path(0)
      assert_link "Seed 7", href: edition_path(7)
      assert_no_selector ".feed__byline, .feed__thumb, .feed__reactions"
    end

    player = accounts_players(:player)
    friend = accounts_players(:moderator)
    Game::Friendship.create!(low_player_id: [ player.id, friend.id ].min, high_player_id: [ player.id, friend.id ].max)
    friend.update!(persona_name: "Sam")
    at = Time.current
    Game::FeedEntry.insert_all!([ { kind: "pull", player_id: friend.id, pack_id: create_pack(friend).id, position: 0,
      card_season_id: catalog_card_seasons(:portal_one).id, rarity: 4, notable: true, occurred_at: at, created_at: at, updated_at: at } ])
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :fr)
    click_steam_sign_in
    assert_signed_in
    assert_selector "#live-ticker .ticker__sentence", text: "Sam a tiré Portal", visible: :all
    assert_no_selector "#live-ticker .ticker__sentence", text: /cours des cartes/, visible: :all

    visit feed_path(locale: :fr, tab: "friends")
    assert_selector ".feed__entry"
    assert_no_selector ".feed__entry--duel-stats"
  end
end
