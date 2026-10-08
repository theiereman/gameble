require "application_system_test_case"
require_relative "../support/catalog_seeds"

class FriendsTest < ApplicationSystemTestCase
  include CatalogSeeds

  setup do
    @player = accounts_players(:player)
    @friend = accounts_players(:moderator)
    @friend.update_columns(persona_name: "Lea", visibility: "friends_only")
    Game::Friendship.create!(low_player_id: [ @player.id, @friend.id ].min, high_player_id: [ @player.id, @friend.id ].max)
    season = publish_sets_draft
    Catalog::CardSeason.where(season_id: season.id).order(rarity: :desc, id: :asc).limit(4).pluck(:id).each do |id|
      Game::Holding.create!(player_id: @friend.id, card_season_id: id, quantity: 1)
    end
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{@player.steam_id}")
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  def sign_in
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    visit friends_path(locale: :en)
  end

  def no_horizontal_scroll?
    page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")
  end

  test "a player opens a friend's profile, sees the showcase and reports it from there" do
    sign_in

    click_on "Lea"

    within("dialog#friend-#{@friend.token}[open]") do
      assert_selector ".friend-profile__name", text: "Lea"
      assert_selector ".friend-profile__showcase .card", count: 3
      assert_selector "a.button--primary[href='#{new_trade_path(locale: :en, friend: @friend.token)}']", text: /propose a trade/i
      take_screenshot
      click_on "REPORT"
    end
    within("dialog#report-dialog-#{@friend.token}[open]") do
      choose "Harassment"
      click_on "SEND THE REPORT"
    end

    assert_current_path friends_path(locale: :en)
    assert_selector ".toast", text: /moderation team will review this profile/i
    assert_equal 1, Accounts::Report.where(reporter_id: @player.id, reported_id: @friend.id).count
  end

  test "on a phone the profile is a bottom sheet that closes back on the friend's name" do
    resize_to(390, 844)
    sign_in

    click_on "Lea"
    within("dialog#friend-#{@friend.token}[open]") do
      assert_selector ".friend-profile__showcase .card", count: 3
      take_screenshot
      find(".modal__close").click
    end

    assert_no_selector "dialog[open]"
    assert_equal "Lea", page.evaluate_script("document.activeElement.textContent")
    assert no_horizontal_scroll?
  end
end
