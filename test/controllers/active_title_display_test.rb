require "test_helper"
require_relative "../support/active_titles"
require_relative "../support/game_packs"
require_relative "../support/holdings"
require_relative "../support/steam_sign_in"

# The title a player wears shows beside their name on the profile screens,
# in the feed and on both sides of a trade, always through the one markup.
class ActiveTitleDisplayTest < ActionDispatch::IntegrationTest
  include ActiveTitles
  include GamePacks
  include Holdings
  include SteamSignIn

  FRENCH_TEXT = "Adepte · Valve".freeze

  setup do
    @alice = accounts_players(:player)
    @bob = accounts_players(:moderator)
    @alice.update!(persona_name: "Hugo")
    @bob.update!(persona_name: "Lea")
    low, high = [ @alice.id, @bob.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
  end

  def shown(selector = ".profile-title") = css_select(selector).map { it.text.squish }

  def open_epic(player)
    create_pack(player, cards: [ fixture_tier_ids[3] ] * 5)
    Game::OpenPack.new.call(player:).value!
  end

  def propose_trade
    portal = catalog_card_seasons(:portal_one).id
    depths = catalog_card_seasons(:rare_card_one).id
    hold(@alice, portal, 1)
    hold(@bob, depths, 1)
    Game::ProposeTrade.new.call(player: @bob, recipient: @alice, offer: { depths => 1 }, request: { portal => 1 }).value!
  end

  test "a public profile shows the title in English and in French, and none for a player who wears none" do
    earn_title(@bob)

    get brother_path(locale: :en, token: @bob.token)
    assert_equal [ ACTIVE_TITLE_TEXT ], shown(".profile-band .profile-title")

    get brother_path(locale: :fr, token: @bob.token)
    assert_equal [ FRENCH_TEXT ], shown(".profile-band .profile-title")

    get brother_path(locale: :en, token: @alice.token)
    assert_empty shown
  end

  test "a title the player earned but did not choose shows nothing, and neither does one no longer earned" do
    earn_title(@bob, equip: false)

    get brother_path(locale: :en, token: @bob.token)
    assert_empty shown

    earn_title(@alice)
    Game::SetTier.where(player_id: @alice.id).delete_all

    get brother_path(locale: :en, token: @alice.token)
    assert_empty shown
  end

  test "the own profile shows the signed-in player's own title beside its pen" do
    earn_title(@alice)
    sign_in(@alice)

    get brother_path(locale: :en, token: @alice.token)

    assert_equal [ ACTIVE_TITLE_TEXT ], shown(".profile-band__line .profile-title")
  end

  test "a friend's profile frame shows their title" do
    earn_title(@bob)
    sign_in(@alice)

    get friend_profile_path(locale: :fr, token: @bob.token)

    assert_equal [ FRENCH_TEXT ], shown(".friend-profile__head .profile-title")
  end

  test "a feed line shows the title of the player it names, in English and in French" do
    earn_title(@alice)
    open_epic(@alice)
    open_epic(@bob)

    get feed_path(locale: :en)
    assert_equal [ ACTIVE_TITLE_TEXT ], shown(".feed__sentence .profile-title").uniq

    get feed_path(locale: :fr)
    assert_equal [ FRENCH_TEXT ], shown(".feed__sentence .profile-title").uniq
  end

  test "the feed reads the tiers of all the players it names in one query" do
    [ @alice, @bob ].each { earn_title(it) && open_epic(it) }
    queries = []
    count = ->(*, payload) { queries << payload[:sql] if payload[:name] == "Game::ProfileTitles" }

    ActiveSupport::Notifications.subscribed(count, "sql.active_record") { get feed_path(locale: :en) }

    assert_equal 1, queries.size
    assert_equal [ ACTIVE_TITLE_TEXT ], shown(".feed__sentence .profile-title").uniq
  end

  test "a trade shows the friend's title on their side and the signed-in player's on their own" do
    earn_title(@alice)
    earn_title(@bob)
    propose_trade
    sign_in(@alice)

    get trades_path(locale: :fr)

    assert_equal [ FRENCH_TEXT ], shown(".trade-side--friend:not(.trade-side--editing) .profile-title")
    assert_equal [ FRENCH_TEXT ], shown(".trade-side--own:not(.trade-side--editing) .profile-title")
  end

  test "a trade side shows no title for a player who wears none" do
    earn_title(@alice)
    propose_trade
    sign_in(@alice)

    get trades_path(locale: :en)

    assert_empty shown(".trade-side--friend .profile-title")
    assert_equal [ ACTIVE_TITLE_TEXT ], shown(".trade-side--own:not(.trade-side--editing) .profile-title")
  end
end
