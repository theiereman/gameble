require "application_system_test_case"
require_relative "../support/catalog_seeds"
require_relative "../support/steam_sign_in"

class FriendsTest < ApplicationSystemTestCase
  include CatalogSeeds
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    @friend = accounts_players(:moderator)
    @friend.update_columns(persona_name: "Lea", visibility: "friends_only")
    Game::Friendship.create!(low_player_id: [ @player.id, @friend.id ].min, high_player_id: [ @player.id, @friend.id ].max)
    season = publish_sets_draft
    Catalog::CardSeason.where(season_id: season.id).order(rarity: :desc, id: :asc).limit(4).pluck(:id).each do |id|
      Game::Holding.create!(player_id: @friend.id, card_season_id: id, quantity: 1)
    end
    mock_steam_sign_in(@player.steam_id)
  end

  def sign_in
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    visit friends_path(locale: :en)
  end

  test "a player finds another by name and invites them with one click" do
    stranger = accounts_players(:administrator)
    stranger.update_columns(persona_name: "Samwise")
    sign_in

    fill_in "Search for a player by name", with: "samw"
    find("#friend-search-results button.friend-search__pick", text: "Samwise").click

    assert_selector ".toast", text: "Invitation sent to Samwise."
    assert_selector ".friends__invitation", text: "Sent to Samwise"
    assert_equal 1, Game::Invitation.where(sender_id: @player.id, recipient_id: stranger.id).count
  end

  test "the friend code field uppercases and places the dash as the code is typed" do
    sign_in

    find_field("Friend code").send_keys("8f2dk9")

    assert_field "Friend code", with: "8F2D-K9"
  end

  test "a player opens a friend's profile, sees no showcase and reports it from its more-actions menu" do
    sign_in

    within(".friends__friend", text: "Lea") { click_on "Lea" }

    within("dialog#friend-#{@friend.token}[open]") do
      assert_selector ".friend-profile__name", text: "Lea"
      assert_no_selector ".friend-profile__showcase"
      assert_selector "a.button--primary[href='#{new_trade_path(locale: :en, friend: @friend.token)}']", text: /\Atrade\z/i
      assert_no_button "Report"
      find("button.friends__more-button[aria-label='More actions for Lea']").click
      assert_selector ".friends__menu:popover-open", text: /report.*remove/im
      click_on "Report"
    end
    within("dialog#report-dialog-#{@friend.token}[open]") { find(".modal__close").click }
    assert_no_selector "dialog#report-dialog-#{@friend.token}[open]"
    assert_selector "dialog#friend-#{@friend.token}[open] button.friends__more-button[aria-label='More actions for Lea']:focus"

    within("dialog#friend-#{@friend.token}[open]") do
      find("button.friends__more-button").click
      click_on "Report"
    end
    within("dialog#report-dialog-#{@friend.token}[open]") do
      choose "Harassment"
      click_on "SEND THE REPORT"
    end

    assert_current_path friends_path(locale: :en)
    assert_selector ".toast", text: /moderation team will review this profile/i
    assert_equal 1, Accounts::Report.where(reporter_id: @player.id, reported_id: @friend.id).count
  end

  test "a player removes a friend from the more-actions menu, after a confirmation that can be cancelled" do
    sign_in

    within(".friends__friend", text: "Lea") do
      assert_no_button "Remove"
      find("button.friends__more-button[aria-label='More actions for Lea']").click
      assert_selector ".friends__menu:popover-open"
      click_on "Remove"
    end
    within("dialog#remove-friend-#{@friend.token}[open]") do
      assert_selector ".modal__title", text: /\Aremove lea\?\z/i
      click_on "Cancel"
    end
    assert_no_selector "dialog[open]"
    assert_no_selector ".friends__menu:popover-open"
    assert_selector ".friends__friend button.friends__more-button[aria-label='More actions for Lea']:focus"

    within(".friends__friend", text: "Lea") do
      find("button.friends__more-button").click
      click_on "Remove"
    end
    within("dialog#remove-friend-#{@friend.token}[open]") { click_on "Remove" }

    assert_selector ".toast", text: "Lea is no longer one of your friends."
    assert_no_selector ".friends__friend"
    assert_not Game::FriendshipBetween.call(@player, @friend)
  end
end
