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

  # Names are uppercased by the stylesheet.
  def earned_tile(name)
    find("#achievements-earned + .achievements__grid .achievement", text: /#{Regexp.escape(name)}/i)
  end

  test "a capsule of the history holding two Rare-or-better cards shows Statistical Non-Compliance earned, in English and in French" do
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in

    visit achievements_path(locale: :en)
    within(earned_tile("Statistical Non-Compliance")) do
      assert_selector ".achievement__condition", text: "Two cards of Rare or better in one standard capsule"
    end

    visit achievements_path(locale: :fr)
    within(earned_tile("Non-conformité statistique")) do
      assert_selector ".achievement__condition", text: "Deux cartes Rare ou mieux dans une capsule standard"
    end
  end
end
