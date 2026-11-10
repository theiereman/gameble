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
    assert_empty template(streams(lea, "update", "menu-trades-badge").sole).children, "hidden at zero"
    assert_nil template(streams(lea, "update", "tab-trades-badge").sole).at_css(".tab-bar__badge"), "hidden at zero"
  end

  def figures(player, locale)
    template(streams(received(player, locale), "update_all", ".balance-chip").sole)
  end

  def post_wallet(player, available:, committed:)
    settings = Game::Market::Settings.create!(Game::Market::StartingSettings::ATTRIBUTES.merge(open: true))
    Game::Market::Ledger.post([ Game::Market::Ledger::Entry.new(player_id: player.id, kind: :mint, available_delta: available + committed,
      committed_delta: 0, settings_id: settings.id) ])
    Game::Market::Ledger.post([ Game::Market::Ledger::Entry.new(player_id: player.id, kind: :hold, available_delta: -committed,
      committed_delta: committed, settings_id: settings.id) ])
  end

  test "a balance notice redraws every balance chip with the compact amounts and the exact twins, in each locale" do
    post_wallet(@hugo, available: 31_599, committed: 12_000)

    PlayerStreamJob.perform_now([ { player_id: @hugo.id, balance: true } ])

    english = figures(@hugo, :en)
    assert_equal "31.5k", english.at_css(".balance-chip__available .picoin-amount__figure").text
    assert_equal "31,599 PiCoins", english.at_css(".balance-chip__available")["aria-label"]
    assert english.at_css(".balance-chip__divider[aria-hidden=true]")
    assert_equal "12k committed", english.at_css(".balance-chip__committed [aria-hidden=true]").text.strip
    assert_equal "12,000 committed", english.at_css(".balance-chip__committed .visually-hidden").text.strip
    assert_equal "12k engagés", figures(@hugo, :fr).at_css(".balance-chip__committed [aria-hidden=true]").text.strip
  end

  test "the French committed text is singular at zero and one" do
    PlayerStreamJob.perform_now([ { player_id: @hugo.id, balance: true } ])
    assert_equal "0 engagé", figures(@hugo, :fr).at_css(".balance-chip__committed [aria-hidden=true]").text.strip
  end

  test "the French committed text is singular at one and plural at two" do
    post_wallet(@hugo, available: 10, committed: 1)
    PlayerStreamJob.perform_now([ { player_id: @hugo.id, balance: true } ])
    assert_equal "1 engagé", figures(@hugo, :fr).at_css(".balance-chip__committed [aria-hidden=true]").text.strip

    post_wallet(@lea, available: 10, committed: 2)
    PlayerStreamJob.perform_now([ { player_id: @lea.id, balance: true } ])
    assert_equal "2 engagés", figures(@lea, :fr).at_css(".balance-chip__committed [aria-hidden=true]").text.strip
  end

  test "no balance stream is sent without a balance notice" do
    PlayerStreamJob.perform_now([ { player_id: @hugo.id, topic: "trades" } ])

    assert_empty streams(received(@hugo, :en), "update_all")
  end

  test "a reactions notice, twice in one batch, sends the reactions signal once and nothing else" do
    PlayerStreamJob.perform_now([ { player_id: @hugo.id, topic: "reactions" }, { player_id: @hugo.id, topic: "reactions" } ])

    english = received(@hugo, :en)
    assert_equal [ "reactions-updated" ], streams(english, "gameble-event").map { it["event"] }
    assert_empty streams(english, "update")
    assert_empty streams(english, "append")
  end

  test "an accepted invitation sends the sender the NOUVEL AMI toast and the friends signal" do
    PlayerStreamJob.perform_now([ { player_id: @hugo.id, topic: "friends", friend_id: @lea.id }, { player_id: @lea.id, topic: "friends" } ])

    french = received(@hugo, :fr)
    toast = template(streams(french, "append", "toasts").sole)
    assert_equal "Nouvel ami", toast.at_css(".toast__title").text
    assert_equal "Léa fait maintenant partie de vos amis.", toast.at_css(".toast__message").text
    assert_equal [ "friends-updated" ], streams(french, "gameble-event").map { it["event"] }
    assert_empty streams(french, "update", "menu-trades-badge"), "no trades badge for a friends notice"
    assert_equal "Léa is now one of your friends.", template(streams(received(@hugo, :en), "append", "toasts").sole).at_css(".toast__message").text

    assert_empty streams(received(@lea, :en), "append"), "the accepting player has their own toast already"
  end

  test "a friends notice sends the invitations to their line of the player menu and the sum to the avatar, in each locale" do
    max = accounts_players(:administrator)
    Game::Invitation.create!(sender_id: max.id, recipient_id: @hugo.id)

    PlayerStreamJob.perform_now([ { player_id: @hugo.id, topic: "friends" }, { player_id: max.id, topic: "friends" } ])

    english = received(@hugo, :en)
    line = template(streams(english, "update", "player-menu-invitations-badge").sole)
    assert_equal "1", line.at_css(".menu-item__badge.menu-item__badge--friends").text
    assert_equal "1 invitation waiting for your answer", line.at_css(".visually-hidden").text
    assert_equal "1", template(streams(english, "update", "player-menu-badge").sole).at_css(".player-chip__badge").text
    assert_empty streams(english, "update", "menu-trades-badge")

    french = received(@hugo, :fr)
    assert_equal "1 invitation en attente de votre réponse", template(streams(french, "update", "player-menu-invitations-badge").sole).at_css(".visually-hidden").text

    sender = received(max, :fr)
    assert_empty template(streams(sender, "update", "player-menu-invitations-badge").sole).children, "hidden at zero"
    assert_nil template(streams(sender, "update", "player-menu-badge").sole).at_css(".player-chip__badge"), "hidden at zero"
  end

  test "a trades notice alone leaves the player menu untouched" do
    PlayerStreamJob.perform_now([ { player_id: @hugo.id, topic: "trades" } ])

    english = received(@hugo, :en)
    assert_empty streams(english, "update", "player-menu-invitations-badge")
    assert_empty streams(english, "update", "player-menu-badge")
  end

  test "an unlocked achievement sends its player the toast in each locale, and no signal" do
    PlayerStreamJob.perform_now([ { player_id: @hugo.id, achievement: "first_booster" }, { player_id: @hugo.id, achievement: "boosters_10" } ])

    french = received(@hugo, :fr)
    toasts = streams(french, "append", "toasts").map { template(it) }
    assert_equal [ "Succès débloqué" ] * 2, toasts.map { it.at_css(".toast__title").text }
    assert_equal [ "Première acquisition approuvée", "Période d'essai validée" ], toasts.map { it.at_css(".toast__message").text }
    assert toasts.all? { it.at_css(".toast[data-toast-after-reveal]") }, "an achievement waits for the opening's reveal"
    assert_empty streams(french, "gameble-event")
    assert_equal [ "menu-achievements-badge", "player-menu-achievements-badge", "player-menu-badge", "plus-achievements-badge" ], streams(french, "update").map { it["target"] }.sort
    english = template(streams(received(@hugo, :en), "append", "toasts").first)
    assert_equal [ "Achievement unlocked", "Your First Authorized Acquisition" ], [ english.at_css(".toast__title").text, english.at_css(".toast__message").text ]
    assert_no_broadcasts PlayerStream.name(@lea, :fr)
  end

  test "an unlocked card back sends its player the toast in each locale, waiting for the reveal" do
    PlayerStreamJob.perform_now([ { player_id: @hugo.id, card_back: "centurion" } ])

    french = streams(received(@hugo, :fr), "append", "toasts").map { template(it) }
    assert_equal [ [ "Dos débloqué", "Centurion" ] ], french.map { [ it.at_css(".toast__title").text, it.at_css(".toast__message").text ] }
    assert french.all? { it.at_css(".toast[data-toast-after-reveal]") }, "a card back waits for the opening's reveal"
    english = streams(received(@hugo, :en), "append", "toasts").map { template(it) }
    assert_equal [ [ "Card back unlocked", "Centurion" ] ], english.map { [ it.at_css(".toast__title").text, it.at_css(".toast__message").text ] }
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
    assert_empty template(streams(english, "update", "menu-trades-badge").sole).children, "hidden at zero"
  end
end
