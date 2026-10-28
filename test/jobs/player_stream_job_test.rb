require "test_helper"

class PlayerStreamJobTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  setup do
    @hugo = accounts_players(:player)
    @lea = accounts_players(:moderator)
    @lea.update!(persona_name: "Léa")
    low, high = [ @hugo.id, @lea.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
    one = catalog_card_seasons(:portal_one).id
    three = catalog_card_seasons(:rare_card_one).id
    Game::Holding.create!(player_id: @lea.id, card_season_id: one, quantity: 3, reserved: 0)
    Game::Holding.create!(player_id: @hugo.id, card_season_id: three, quantity: 2, reserved: 0)
    Game::ProposeTrade.new.call(player: @lea, recipient: @hugo, offer: { one => 1 }, request: { three => 1 }).value!
  end

  def received(player, locale)
    Nokogiri::HTML5.fragment(ActiveSupport::JSON.decode(broadcasts(PlayerStream.name(player, locale)).sole))
  end

  def streams(fragment, action, target = nil)
    fragment.css(target ? "turbo-stream[action='#{action}'][target='#{target}']" : "turbo-stream[action='#{action}']")
  end

  def template(stream) = Nokogiri::HTML5.fragment(stream.at_css("template").inner_html)

  test "a trades notice sends the waiting badge and the trades signal, in each locale" do
    PlayerStreamJob.perform_now([ { player_id: @hugo.id, topic: "trades" }, { player_id: @lea.id, topic: "trades" } ])

    english = received(@hugo, :en)
    menu = template(streams(english, "update", "menu-trades-badge").sole)
    assert_equal "1", menu.at_css(".menu-item__badge.menu-item__badge--alert").text
    assert_equal "1 trade waiting for you", menu.at_css(".visually-hidden").text
    tab = template(streams(english, "update", "tab-trades-badge").sole)
    assert_equal "1", tab.at_css(".tab-bar__badge--alert").text
    assert_equal [ "trades-updated" ], streams(english, "gameble-event").map { it["event"] }
    assert_empty streams(english, "append")

    french = received(@hugo, :fr)
    assert_equal "1 échange en attente de vous", template(streams(french, "update", "menu-trades-badge").sole).at_css(".visually-hidden").text

    lea = received(@lea, :en)
    assert_equal "0", template(streams(lea, "update", "menu-trades-badge").sole).at_css(".menu-item__badge--zero").text
    assert_nil template(streams(lea, "update", "tab-trades-badge").sole).at_css(".tab-bar__badge"), "hidden at zero"
  end

  test "an accepted invitation sends the sender the NOUVEL AMI toast and the friends signal" do
    PlayerStreamJob.perform_now([ { player_id: @hugo.id, topic: "friends", friend_id: @lea.id }, { player_id: @lea.id, topic: "friends" } ])

    french = received(@hugo, :fr)
    toast = template(streams(french, "append", "toasts").sole)
    assert_equal "Nouvel ami", toast.at_css(".toast__title").text
    assert_equal "Léa fait maintenant partie de vos amis.", toast.at_css(".toast__message").text
    assert_equal [ "friends-updated" ], streams(french, "gameble-event").map { it["event"] }
    assert_empty streams(french, "update"), "no badge for a friends notice"
    assert_equal "Léa is now one of your friends.", template(streams(received(@hugo, :en), "append", "toasts").sole).at_css(".toast__message").text

    assert_empty streams(received(@lea, :en), "append"), "the accepting player has their own toast already"
  end

  test "an unlocked achievement sends its player the toast in each locale, and no signal" do
    PlayerStreamJob.perform_now([ { player_id: @hugo.id, achievement: "first_booster" }, { player_id: @hugo.id, achievement: "boosters_10" } ])

    french = received(@hugo, :fr)
    toasts = streams(french, "append", "toasts").map { template(it) }
    assert_equal [ "Succès débloqué" ] * 2, toasts.map { it.at_css(".toast__title").text }
    assert_equal [ "Première capsule", "10 capsules" ], toasts.map { it.at_css(".toast__message").text }
    assert toasts.all? { it.at_css(".toast[data-toast-after-reveal]") }, "an achievement waits for the opening's reveal"
    assert_empty streams(french, "gameble-event")
    assert_empty streams(french, "update")
    english = template(streams(received(@hugo, :en), "append", "toasts").first)
    assert_equal [ "Achievement unlocked", "First capsule" ], [ english.at_css(".toast__title").text, english.at_css(".toast__message").text ]
    assert_no_broadcasts PlayerStream.name(@lea, :fr)
  end

  test "an unlocked card back sends its player the toast in each locale, waiting for the reveal" do
    PlayerStreamJob.perform_now([ { player_id: @hugo.id, card_back: "confrere" } ])

    french = streams(received(@hugo, :fr), "append", "toasts").map { template(it) }
    assert_equal [ [ "Dos débloqué", "Confrère" ] ], french.map { [ it.at_css(".toast__title").text, it.at_css(".toast__message").text ] }
    assert french.all? { it.at_css(".toast[data-toast-after-reveal]") }, "a card back waits for the opening's reveal"
    english = streams(received(@hugo, :en), "append", "toasts").map { template(it) }
    assert_equal [ [ "Card back unlocked", "Confrère" ] ], english.map { [ it.at_css(".toast__title").text, it.at_css(".toast__message").text ] }
    assert_no_broadcasts PlayerStream.name(@lea, :fr)
  end

  test "a player's notices go in one message per locale" do
    PlayerStreamJob.perform_now([ { player_id: @hugo.id, topic: "trades" }, { player_id: @hugo.id, topic: "friends", friend_id: @lea.id },
      { player_id: @hugo.id, topic: "trades" } ])

    english = received(@hugo, :en)
    assert_equal %w[trades-updated friends-updated], streams(english, "gameble-event").map { it["event"] }
    assert_equal 1, streams(english, "update", "menu-trades-badge").size
    assert_equal 1, streams(english, "append", "toasts").size
  end

  test "a banned player or a deleted account gets nothing, and a banned friend is not named" do
    banned = accounts_players(:banned)
    deleted = accounts_players(:administrator)
    Accounts::DeletePlayer.new.call(player: deleted).value!

    PlayerStreamJob.perform_now([ { player_id: banned.id, topic: "trades" }, { player_id: deleted.id, topic: "friends" },
      { player_id: @hugo.id, topic: "friends", friend_id: banned.id } ])

    %i[en fr].each do |locale|
      assert_no_broadcasts PlayerStream.name(banned.reload, locale)
      assert_no_broadcasts PlayerStream.name(deleted.reload, locale)
      assert_empty streams(received(@hugo, locale), "append")
    end
  end

  test "a friend whose account was deleted before the job ran is not named, and nothing fails" do
    Accounts::DeletePlayer.new.call(player: @lea).value!

    PlayerStreamJob.perform_now([ { player_id: @hugo.id, topic: "friends", friend_id: @lea.id }, { player_id: @hugo.id, topic: "trades" } ])

    english = received(@hugo, :en)
    assert_empty streams(english, "append")
    assert_equal "0", template(streams(english, "update", "menu-trades-badge").sole).at_css(".menu-item__badge--zero").text
  end
end
