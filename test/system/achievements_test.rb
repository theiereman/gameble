require "application_system_test_case"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

# The achievements screen of a player whose history earned an achievement
# through the backfill: the tile sits in the earned group, in each locale.
class AchievementsTest < ApplicationSystemTestCase
  include GamePacks
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    common, _, rare, epic, = fixture_tier_ids
    create_pack(@player, cards: [ rare, epic ] + [ common ] * 3, opened_at: 1.day.ago)
    Game::BackfillAchievementsJob.perform_now
    mock_steam_sign_in(@player.steam_id)
  end

  def earned_tile(name)
    find("#achievements-earned + .achievements__grid .achievement", text: name)
  end

  test "a capsule of the history holding two Rare-or-better cards shows Statistical Non-Compliance earned, in English and in French" do
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in

    visit achievements_path(locale: :en)
    within(earned_tile("Statistical Non-Compliance")) do
      assert_selector ".achievement__condition", text: "Two Rare or better cards in one standard capsule"
    end

    visit achievements_path(locale: :fr)
    within(earned_tile("Non-conformité statistique")) do
      assert_selector ".achievement__condition", text: "Deux cartes Rares ou mieux dans une capsule standard"
    end
  end

  test "each achievement is one row, with its back beside the text on desktop and below it on a phone" do
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    visit achievements_path(locale: :en)

    assert_selector ".achievement__name", text: "Statistical Non-Compliance"
    assert_selector ".achievement .achievement__side", minimum: 1
    assert_equal 1, all(".achievement").map { it.evaluate_script("this.getBoundingClientRect().left") }.uniq.size
    assert side_is(:beside)

    page.current_window.resize_to(375, 800)

    assert side_is(:below)
  end

  private
    def side_is(placement)
      page.document.synchronize do
        row = first(".achievement:has(.achievement__side)")
        text_box = row.find(".achievement__text").evaluate_script("this.getBoundingClientRect().toJSON()")
        side_box = row.find(".achievement__side").evaluate_script("this.getBoundingClientRect().toJSON()")
        placed = placement == :beside ? side_box["left"] >= text_box["right"] : side_box["top"] >= text_box["bottom"]
        raise Capybara::ExpectationNotMet, "the side block is not #{placement} the text" unless placed
        true
      end
    end
end
