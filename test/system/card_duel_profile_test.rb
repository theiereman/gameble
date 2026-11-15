require "application_system_test_case"
require_relative "../support/holdings"
require_relative "../support/steam_sign_in"

# A card's detail shows its edition's duel profile after the facts: the five stats in words with their raw values, the
# trump marked, the date of the computation. A visitor reads it through a profile's album; the public card page stays the card alone.
class CardDuelProfileTest < ApplicationSystemTestCase
  include Holdings
  include SteamSignIn

  setup do
    portal = catalog_card_seasons(:portal_one)
    portal.update_columns(review_count: 1_000)
    assert Game::FirstDiscovery.exists?(card_season_id: portal.id)
    hold(accounts_players(:player), portal.id)
    Game::ComputeDuelStats.new.call(reason: "first", now: Time.utc(2026, 11, 16, 0, 0)).value!
  end

  def sign_in(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  def discovery_day
    day = Game::FirstDiscovery.find_by!(card_season_id: catalog_card_seasons(:portal_one).id).discovered_at.to_date
    I18n.l(day, format: day.day == 1 ? :long_day_first : :long_day, locale: :en)
  end

  def stat_row(name) = find(".duel-profile__stat", text: name)

  def assert_portal_duel_profile
    assert_selector ".card-detail__facts + .duel-profile"
    within ".duel-profile" do
      assert_selector ".duel-profile__heading", text: "DUEL"
      assert_equal %w[POPULARITY RATING RELEASE DISCOVERY CIRCULATION], all(".duel-profile__name").map { it.text.split.first }
      assert_selector ".duel-profile__stat--trump", count: 1
      within(stat_row("RATING")) do
        assert_selector ".duel-profile__trump", text: "TRUMP"
        assert_selector ".duel-profile__value", text: "95% positive"
        assert_selector ".duel-profile__words", text: "Better rated than 90% of cards"
        assert_selector "progress.duel-profile__bar[value='90.0'][aria-hidden='true']", visible: :all
      end
      within(stat_row("POPULARITY")) do
        assert_selector ".duel-profile__value", text: "1,000 reviews"
        assert_selector ".duel-profile__words", text: "More popular than 50% of cards"
      end
      within(stat_row("RELEASE")) do
        assert_selector ".duel-profile__value", text: "October 10, 2007"
        assert_selector ".duel-profile__words", text: "Older than 70% of cards"
      end
      within(stat_row("DISCOVERY")) do
        assert_selector ".duel-profile__value", text: discovery_day
        assert_selector ".duel-profile__words", text: "Discovered before 50% of cards"
      end
      within(stat_row("CIRCULATION")) do
        assert_selector ".duel-profile__value", text: "1 player"
        assert_selector ".duel-profile__words", text: "More widespread than 50% of Epic cards"
      end
      assert_selector ".duel-profile__dated", text: "Values of November 16, 2026"
    end
  end

  test "a signed-in player reads the duel profile of the card's edition" do
    sign_in(accounts_players(:player))

    visit card_season_path(locale: :en, slug: "portal", number: 1)

    assert_selector ".card-detail h1", text: "Portal"
    assert_portal_duel_profile
  end

  test "a visitor reads it through a profile's album, never on the public card page" do
    visit card_season_path(locale: :en, slug: "portal", number: 1, brother: accounts_players(:player).token)

    assert_selector ".card-detail h1", text: "Portal"
    assert_portal_duel_profile

    visit card_path(locale: :en, slug: "portal")

    assert_selector ".public-card h1", text: "Portal"
    assert_no_selector ".duel-profile"
  end

  test "a card-season without a profile shows no duel block" do
    Game::DuelStat.delete_all
    sign_in(accounts_players(:player))

    visit card_season_path(locale: :en, slug: "portal", number: 1)

    assert_selector ".card-detail h1", text: "Portal"
    assert_no_selector ".duel-profile"
  end
end
