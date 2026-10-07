require "test_helper"
require_relative "../support/counting_rate_limit"

# The trades screen: the list in three groups, a trade's board by its token
# with the actions of its state, the island that turns a board waiting for
# the player into a counter-proposal, the counter-proposal form, the draft of
# a new trade and its sending, the swap after an acceptance, the orange
# waiting badge on menu 03 and the ÉCHANGES tab, and the sign-in panel for a
# visitor.
class TradesControllerTest < ActionDispatch::IntegrationTest
  include CountingRateLimit

  setup do
    OmniAuth.config.test_mode = true
    @alice = accounts_players(:player)
    @bob = accounts_players(:moderator)
    @carol = accounts_players(:administrator)
    @alice.update!(persona_name: "Hugo")
    @bob.update!(persona_name: "Lea")
    @carol.update!(persona_name: "Max")
    @portal = catalog_card_seasons(:portal_one).id
    @soldier = catalog_card_seasons(:common_card_one).id
    @depths = catalog_card_seasons(:rare_card_one).id
    [ @bob, @carol ].each { befriend(@alice, it) }
    hold(@alice, @portal, 3)
    hold(@alice, @soldier, 1)
    hold(@bob, @depths, 2)
    hold(@carol, @depths, 1)
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  def befriend(first, second)
    low, high = [ first.id, second.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
  end

  def hold(player, card_season_id, quantity)
    Game::Holding.create!(player_id: player.id, card_season_id:, quantity:, reserved: 0)
  end

  def holding(player, card_season_id) = Game::Holding.find_by(player_id: player.id, card_season_id:)

  def propose(player, recipient, offer:, request:)
    Game::ProposeTrade.new.call(player:, recipient:, offer:, request:).value!
  end

  def sign_in(player, origin: "/fr")
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{player.steam_id}")
    post "/auth/steam", params: { origin: }
    follow_redirect!
  end

  # Lea proposes Profondeurs bleues for Portal ×2: Hugo's turn.
  def from_lea = propose(@bob, @alice, offer: { @depths => 1 }, request: { @portal => 2 })

  test "a visitor is sent home to sign in, and menu 03 and the tab open the sign-in panel" do
    trade = from_lea

    get trades_path(locale: :fr)
    assert_redirected_to home_path(locale: :fr)
    post accept_trade_path(token: trade.token, locale: :fr)
    assert_redirected_to home_path(locale: :fr)
    assert trade.reload.open?

    get home_path(locale: :fr)
    assert_select ".hub-menu button.menu-item[aria-keyshortcuts='3'][aria-haspopup=dialog]", /Échanges/
    assert_select ".tab-bar button.tab-bar__tab[aria-haspopup=dialog]", /Échanges/
  end

  test "the list groups the trades, and the first board shows beside it" do
    from_lea
    propose(@alice, @carol, offer: { @soldier => 1 }, request: { @depths => 1 })
    sign_in @alice

    get trades_path(locale: :fr)

    assert_response :success
    assert_select "title", /Échanges/
    assert_select ".trades--list"
    assert_equal [ "En attente de vous", "En attente de leur réponse" ], css_select(".trades__group").map { it.text.strip }
    rows = css_select(".trade-row")
    assert_equal 2, rows.size
    assert_match(/Lea/, rows[0].text)
    assert_match(/Profondeurs bleues contre Portal ×2/, rows[0].text)
    assert_match(/expire dans 7 j/, rows[0].text)
    assert_equal "À vous", rows[0].at_css(".trade-chip--alert").text
    assert_match(/Profondeurs bleues contre Soldat de plomb/, rows[1].text)
    assert_equal "En attente", rows[1].at_css(".trade-chip--accent").text
    assert_select ".trade-board .trade-board__title", "Échange avec Lea"
  end

  test "the board of a trade waiting for the player: its line, expiry, reserved copies and three actions" do
    trade = from_lea
    sign_in @alice

    get trade_path(token: trade.token, locale: :fr)

    assert_response :success
    assert_select ".trades--board"
    assert_select ".trade-row[aria-current=page][href=?]", trade_path(token: trade.token, locale: :fr)
    assert_select ".top-bar__phone-back[href='/fr/trades']", /Liste/
    assert_select ".trade-board" do
      assert_select ".trade-chip--alert", "À vous"
      assert_select ".trade-board__expiry", /Expire dans\s+7 j/
      assert_select ".trade-board__message", "Lea vous propose cet échange."
      assert_select ".trade-side--friend .trade-side__label", "Lea donne"
      assert_select ".trade-side--friend .trade-card__reserved", "Réservée"
      assert_select ".trade-side--friend .card", 1
      assert_select ".trade-side--own .trade-side__label", "Vous donnez"
      assert_select ".trade-side--own .trade-card__quantity", /×2/
      assert_select ".trade-side--own .trade-side__count", "1 carte · 2 ex."
      assert_select ".trade-side--own .trade-card__reserved", 0
      assert_select "form[action=?] button", accept_trade_path(token: trade.token, locale: :fr), "Accepter"
      assert_select "a[href=?]", counter_trade_path(token: trade.token, locale: :fr), "Contre-proposer"
      assert_select "form[action=?] button", decline_trade_path(token: trade.token, locale: :fr), "Refuser"
    end
    assert_no_match(/trade[_-]id|value="#{trade.id}"/, response.body)
  end

  test "the proposer sees their reserved copies and cancels; the copies are released" do
    trade = propose(@alice, @bob, offer: { @portal => 2 }, request: { @depths => 1 })
    sign_in @alice

    get trade_path(token: trade.token, locale: :fr)
    assert_select ".trade-chip--accent", "En attente"
    assert_select ".trade-board__message", "En attente de la réponse de Lea."
    assert_select ".trade-side--own .trade-card__reserved", "2 réservées"
    assert_select ".trade-board__actions form button", 1

    post cancel_trade_path(token: trade.token, locale: :fr)
    assert_redirected_to trade_path(token: trade.token, locale: :fr)
    follow_redirect!
    assert_select ".toast", /Proposition annulée.*Vos cartes ne sont plus réservées\./m
    assert_select ".trade-chip--muted", "Clos"
    assert_select ".trade-board__expiry", /annulé à l'instant/
    assert_select ".trade-side--friend .trade-side__label", "Lea proposait"
    assert_select ".trade-board__actions form", 0
    assert_equal 0, holding(@alice, @portal).reserved
  end

  test "accepting swaps the cards, says what joined the collection and lowers the badge" do
    trade = from_lea
    sign_in @alice
    get home_path(locale: :fr)
    assert_select ".hub-menu a.menu-item[href='/fr/trades'] .menu-item__badge--alert", "1"
    assert_select ".hub-menu a.menu-item[href='/fr/trades'] .visually-hidden", "1 échange en attente de vous"
    assert_select ".tab-bar a.tab-bar__tab[href='/fr/trades'] .tab-bar__badge--alert", "1"

    post accept_trade_path(token: trade.token, locale: :fr)
    assert_redirected_to trade_path(token: trade.token, locale: :fr)
    follow_redirect!

    assert_select ".toast", /Échange conclu.*Profondeurs bleues rejoint votre collection\./m
    assert_select ".trade-chip--lime", "Conclu"
    assert_select ".trade-board__message[tabindex='-1']", "Échange conclu."
    assert_select ".trade-board[data-controller~='trade-swap'][data-trade-swap-play-value='true']"
    assert_select ".trade-side--friend .trade-side__label", "Lea a reçu"
    assert_select ".trade-side--friend .card", /Portal/
    assert_select ".trade-side--friend .trade-card__quantity", /×2/
    assert_select ".trade-side--friend .trade-card__new", 0
    assert_select ".trade-side--own .trade-side__label", "Vous avez reçu"
    assert_select ".trade-side--own .card", /Profondeurs bleues/
    assert_select ".trade-side--own .trade-card__new", "Nouveau"
    assert_select ".trades__group", "Terminés récemment"
    assert_equal 1, holding(@alice, @portal).quantity
    assert_equal 1, holding(@alice, @depths).quantity

    get trade_path(token: trade.token, locale: :fr)
    assert_select ".trade-board[data-controller~='trade-swap']"
    assert_select "[data-trade-swap-play-value]", 0

    get home_path(locale: :fr)
    assert_select ".hub-menu a.menu-item[href='/fr/trades'] .menu-item__badge--zero", "0"
    assert_select ".tab-bar__badge", 0
  end

  test "an acceptance refused shows the reason on the board and in a toast; nothing moves" do
    trade = from_lea
    Game::Holding.where(player_id: @alice.id, card_season_id: @portal).update_all(quantity: 1)
    sign_in @alice

    post accept_trade_path(token: trade.token, locale: :fr)
    follow_redirect!

    message = I18n.t("errors.game.requested_cards_unavailable", locale: :fr)
    assert_select ".trade-board__error[role=alert]", message
    assert_select ".toast--alert", /Exemplaires insuffisants/
    assert_select ".trade-chip--alert", "À vous"
    assert trade.reload.open?
  end

  test "declining tells the friend's name" do
    trade = from_lea
    sign_in @alice

    post decline_trade_path(token: trade.token, locale: :fr)
    follow_redirect!

    assert_select ".toast", /Échange refusé.*Votre réponse a été envoyée à Lea\./m
    assert_select ".trade-board__expiry", /refusé à l'instant/
    assert_equal "declined", trade.reload.status
  end

  test "a closed trade offers a new one with the friend, while they are still friends" do
    trade = from_lea
    sign_in @alice
    post decline_trade_path(token: trade.token, locale: :fr)

    get trade_path(token: trade.token, locale: :fr)
    assert_select ".trade-board__actions a.button--primary[href=?]", new_trade_path(locale: :fr, friend: @bob.token), "Nouvel échange avec Lea"

    Game::Friendship.delete_all
    get trade_path(token: trade.token, locale: :fr)
    assert_select ".trade-board__actions a", 0
  end

  test "the counter form edits both sides' quantities and sends the counter-proposal" do
    trade = from_lea
    sign_in @alice

    get counter_trade_path(token: trade.token, locale: :fr)
    assert_response :success
    assert_select ".trade-board--editing form[action=?][method=post]", counter_trade_path(token: trade.token, locale: :fr)
    assert_select ".trade-side--editing", 2
    assert_select ".trade-board__message", "Modifiez ce que vous donnez et ce que vous demandez, puis renvoyez."
    assert_select "input[name='give[portal--s1]'][value='2'][min='0'][max='3']"
    assert_select "input[name='take[blue-depths--s1]'][value='1'][max='2']"
    assert_select "button[type=submit]", "Renvoyer la contre-proposition"
    assert_select "a[href=?]", trade_path(token: trade.token, locale: :fr), "Annuler les modifications"

    round = "#{@alice.token}:#{trade.token}:#{trade.expires_at.to_i}"
    post counter_trade_path(token: trade.token, locale: :fr), params: { give: { "portal--s1" => "1" }, take: { "blue-depths--s1" => "2" } }
    assert_redirected_to trade_path(token: trade.token, locale: :fr)
    follow_redirect!

    assert_select ".toast", /Proposition envoyée.*Lea a 7 jours pour répondre\./m
    assert_select ".trade-chip--accent", "En attente"
    assert_select ".trade-board[data-trade-board-forget-value=?]", round
    trade.reload
    assert_equal @alice.id, trade.proposer_id
    assert_equal({ "offer" => [ [ @portal, 1 ] ], "request" => [ [ @depths, 2 ] ] },
      trade.items.group_by(&:side).transform_values { |items| items.map { [ it.card_season_id, it.quantity ] } })
    assert_equal 1, holding(@alice, @portal).reserved
    assert_equal 0, holding(@bob, @depths).reserved
  end

  test "a counter that empties a side is refused on its form" do
    trade = from_lea
    sign_in @alice

    post counter_trade_path(token: trade.token, locale: :fr), params: { give: { "portal--s1" => "0" }, take: { "blue-depths--s1" => "1" } }

    assert_redirected_to counter_trade_path(token: trade.token, locale: :fr)
    follow_redirect!
    assert_select ".trade-board__error", I18n.t("errors.game.invalid_offer", locale: :fr)
    assert_equal @bob.id, trade.reload.proposer_id
  end

  def island_props
    element = css_select("[data-controller='turbo-mount-trade-board']").first
    assert element, "the TradeBoard island is mounted"
    JSON.parse(element["data-turbo-mount-trade-board-props-value"])
  end

  test "the counter form mounts the trade board island with both holders' cards, over the quantity fields" do
    hold(@bob, @soldier, 3)
    trade = from_lea
    # Another trade reserves one of Hugo's three Portal.
    propose(@alice, @carol, offer: { @portal => 1 }, request: { @depths => 1 })
    sign_in @alice

    get counter_trade_path(token: trade.token, locale: :fr)
    assert_response :success
    assert_select ".trade-board--editing .trade-island input[name='give[portal--s1]'][max='2'][form='trade-counter-form']"
    assert_select ".trade-board__actions form#trade-counter-form[data-controller='trade-send']:not([hidden]) #trade-send-reason[hidden]",
      "Choisissez les cartes de chaque côté."
    assert_select ".trade-board__actions [data-trade-board-target='readActions'][hidden]"

    props = island_props
    friend, own = props.fetch("sides")
    assert_equal %w[friend take], friend.values_at("side", "field")
    assert_equal %w[own give], own.values_at("side", "field")
    assert_equal "Choisir dans la collection de Lea", friend.fetch("pickerTitle")
    assert_equal "Cartes de Lea", friend.fetch("pickerTitleShort")
    assert_equal "Placer mes cartes", own.fetch("add")
    assert_equal [ { "key" => "blue-depths--s1", "quantity" => 1 } ], friend.fetch("lines")
    assert_equal [ { "key" => "portal--s1", "quantity" => 2 } ], own.fetch("lines")

    # Hugo's cards: copies, those reserved elsewhere, the free ones; ordered by number.
    assert_equal [ [ "tin-soldier--s1", 1, 0, 1 ], [ "portal--s1", 3, 1, 2 ] ],
      own.fetch("cards").map { it.values_at("key", "owned", "reserved", "max") }
    # Lea's: what she holds, her reservations her own.
    assert_equal [ [ "tin-soldier--s1", 3, 0, 3 ], [ "blue-depths--s1", 2, 0, 2 ] ],
      friend.fetch("cards").map { it.values_at("key", "owned", "reserved", "max") }
    face = own.fetch("cards").last.fetch("face")
    assert_includes face, "card--s"
    assert_includes face, "Portal"
    assert_no_match(/style=/, face)
    assert_no_match(/"id"|card_season_id/, props.to_json)
    assert_equal "Modifiez ce que vous donnez et ce que vous demandez, puis renvoyez.", props.fetch("message")
    assert_equal "Lea vous propose cet échange.", props.fetch("readMessage")
    assert props.fetch("editing")
    assert_equal "trade-counter-form", props.fetch("formId")
    assert_equal "#{@alice.token}:#{trade.token}:#{trade.reload.expires_at.to_i}", props.fetch("draftKey")
    assert_equal({ "one" => "%{count} carte", "other" => "%{count} cartes" }, props.dig("strings", "cards"))
    assert_equal "Retirer %{title}", props.dig("strings", "remove")
    assert_equal I18n.t("trades.side.none.friend_none_owned", name: "Lea", locale: :fr), friend.fetch("none")
    assert_equal I18n.t("trades.side.none.none_owned", locale: :fr), own.fetch("none")
    assert_equal I18n.t("trades.side.none.all_reserved", locale: :fr), props.dig("strings", "noneAllReserved")
  end

  test "a counter places cards the side's holder holds that were not on it" do
    hold(@bob, @soldier, 3)
    trade = from_lea
    sign_in @alice

    post counter_trade_path(token: trade.token, locale: :fr),
      params: { give: { "portal--s1" => "1", "tin-soldier--s1" => "1" }, take: { "tin-soldier--s1" => "2" } }

    assert_redirected_to trade_path(token: trade.token, locale: :fr)
    trade.reload
    assert_equal @alice.id, trade.proposer_id
    assert_equal({ "offer" => [ [ @soldier, 1 ], [ @portal, 1 ] ].sort, "request" => [ [ @soldier, 2 ] ] },
      trade.items.group_by(&:side).transform_values { |items| items.map { [ it.card_season_id, it.quantity ] }.sort })
    assert_equal 1, holding(@alice, @soldier).reserved
    assert_equal 0, holding(@bob, @depths).reserved
  end

  test "a counter naming a card its holder does not hold is refused, and nothing changes" do
    trade = from_lea
    sign_in @alice

    # Hugo holds no Blue Depths to give; Lea holds no Golden Crown to ask for.
    post counter_trade_path(token: trade.token, locale: :fr), params: { give: { "blue-depths--s1" => "1" }, take: { "blue-depths--s1" => "1" } }
    assert_redirected_to counter_trade_path(token: trade.token, locale: :fr)
    follow_redirect!
    assert_select ".trade-board__error", I18n.t("errors.game.invalid_offer", locale: :fr)
    assert_equal I18n.t("errors.game.invalid_offer", locale: :fr), island_props.fetch("error")

    post counter_trade_path(token: trade.token, locale: :fr), params: { give: { "portal--s1" => "1" }, take: { "golden-crown--s1" => "1" } }
    follow_redirect!
    assert_select ".trade-board__error", I18n.t("errors.game.invalid_request", locale: :fr)
    assert_equal @bob.id, trade.reload.proposer_id
    assert_equal 1, holding(@bob, @depths).reserved
  end

  test "the counter form is only for the player's turn, and a counter sent off turn says why on the board" do
    trade = propose(@alice, @bob, offer: { @portal => 1 }, request: { @depths => 1 })
    sign_in @alice

    get counter_trade_path(token: trade.token, locale: :fr)
    assert_redirected_to trade_path(token: trade.token, locale: :fr)

    post counter_trade_path(token: trade.token, locale: :fr), params: { give: { "portal--s1" => "1" }, take: { "blue-depths--s1" => "1" } }
    follow_redirect!
    follow_redirect!
    assert_select ".trade-board__error", I18n.t("errors.game.not_allowed", locale: :fr)
  end

  test "a board waiting for the player carries the island, ready to counter in place" do
    trade = from_lea
    sign_in @alice

    get trade_path(token: trade.token, locale: :fr)

    assert_select ".trade-board[data-controller~='trade-board'][data-trade-board-focus-value='true']"
    assert_select ".trade-board[data-trade-board-counter-url-value=?][data-trade-board-board-url-value=?]",
      counter_trade_path(token: trade.token, locale: :fr), trade_path(token: trade.token, locale: :fr)
    assert_select ".trade-chip--alert[data-trade-board-target='chip']:not([hidden])", "À vous"
    assert_select ".trade-chip--accent[data-trade-board-target='editingChip'][hidden]", "En édition"
    assert_select "[data-trade-board-target='readActions']:not([hidden])" do
      assert_select "[data-action='click->trade-board#edit'] a[href=?]", counter_trade_path(token: trade.token, locale: :fr), "Contre-proposer"
    end
    assert_select "form#trade-counter-form[hidden][action=?]", counter_trade_path(token: trade.token, locale: :fr) do
      assert_select "button[type=submit]", "Renvoyer la contre-proposition"
      assert_select "[data-action='click->trade-board#undo'] a[href=?]", trade_path(token: trade.token, locale: :fr), "Annuler les modifications"
    end
    assert_select "dialog#trade-undo-dialog[data-trade-board-target='undoDialog']" do
      assert_select ".modal__title", "Annuler les modifications ?"
      assert_select "#trade-undo-dialog-text", "Ce que vous avez changé sera perdu et la proposition de Lea reviendra telle quelle."
      assert_select "button[data-action='trade-board#restore']", "Annuler les modifications"
      assert_select "button[data-action='dialog#close']", "Continuer à modifier"
    end
    assert_select ".trade-island .trade-side--friend .trade-card__reserved", "Réservée"

    props = island_props
    assert_not props.fetch("editing")
    assert_equal "Lea vous propose cet échange.", props.fetch("readMessage")
    assert_equal "#{@alice.token}:#{trade.token}:#{trade.expires_at.to_i}", props.fetch("draftKey")
    friend, own = props.fetch("sides")
    assert_includes friend.fetch("readHtml"), "Réservée"
    assert_includes friend.fetch("readHtml"), "Lea donne"
    assert_includes own.fetch("readHtml"), "×2"
    assert_no_match(/style=|trade[_-]id/, props.to_json)
  end

  test "a draft with a friend: an empty board in edition, kept in the browser, nothing on the server" do
    propose(@alice, @carol, offer: { @soldier => 1 }, request: { @depths => 1 })
    sign_in @alice

    assert_no_difference -> { Game::Trade.count } do
      get new_trade_path(locale: :fr, friend: @bob.token)
    end

    assert_response :success
    assert_select "title", /Échange avec Lea/
    assert_select ".trade-row", 1
    assert_select ".trade-board[data-controller='trade-board'][data-trade-board-draft-value=?]", "#{@alice.token}:#{@bob.token}" do
      assert_select ".trade-board__title", "Échange avec Lea"
      assert_select ".trade-chip--accent", "Brouillon"
      assert_select ".trade-board__expiry", "Valable 7 jours après l'envoi"
      assert_select ".trade-side--editing", 2
      assert_select ".trade-side--friend .trade-side__label", "Lea donne"
      assert_select ".trade-side--own .trade-side__label", "Vous donnez"
      assert_select ".trade-board__message", "Choisissez les cartes de chaque côté."
      assert_select "form#trade-draft-form[action=?][data-controller='trade-send']", trades_path(locale: :fr) do
        assert_select "input[type=hidden][name=friend][value=?]", @bob.token
        assert_select "button[type=submit]", "Envoyer la proposition"
        assert_select "[data-action='click->trade-board#abandon'] a[href=?]", trades_path(locale: :fr), "Abandonner"
      end
    end

    props = island_props
    assert props.fetch("editing")
    assert_nil props.fetch("readMessage")
    assert_equal "trade-draft-form", props.fetch("formId")
    assert_equal "#{@alice.token}:#{@bob.token}", props.fetch("draftKey")
    friend, own = props.fetch("sides")
    assert_equal [ [], [] ], [ friend.fetch("lines"), own.fetch("lines") ]
    assert_equal [ "blue-depths--s1" ], friend.fetch("cards").map { it.fetch("key") }
    assert_equal [ [ "tin-soldier--s1", 0 ], [ "portal--s1", 3 ] ], own.fetch("cards").map { it.values_at("key", "max") }
  end

  test "a draft is only for a friend the player may trade with" do
    sign_in @alice

    get new_trade_path(locale: :fr, friend: @alice.token)
    assert_response :not_found
    get new_trade_path(locale: :fr, friend: "1" * 24)
    assert_response :not_found
    get new_trade_path(locale: :fr)
    assert_response :not_found
    befriend(@alice, accounts_players(:banned))
    get new_trade_path(locale: :fr, friend: accounts_players(:banned).token)
    assert_response :not_found
    Game::Friendship.where(low_player_id: [ @alice.id, @carol.id ].min).delete_all
    get new_trade_path(locale: :fr, friend: @carol.token)
    assert_response :not_found
  end

  test "a visitor asking for a draft is sent home to sign in" do
    get new_trade_path(locale: :fr, friend: @bob.token)
    assert_redirected_to home_path(locale: :fr)
    post trades_path(locale: :fr), params: { friend: @bob.token, give: { "portal--s1" => "1" }, take: { "blue-depths--s1" => "1" } }
    assert_redirected_to home_path(locale: :fr)
    assert_equal 0, Game::Trade.count
  end

  test "a draft with a friend already trading opens that trade, one at a time" do
    trade = from_lea
    sign_in @alice

    get new_trade_path(locale: :fr, friend: @bob.token)

    assert_redirected_to trade_path(token: trade.token, locale: :fr)
    follow_redirect!
    assert_select ".trade-board__error[role=alert]", "Un échange est déjà ouvert avec Lea."
    assert_select ".toast--alert", /Un échange à la fois/
  end

  test "sending a draft proposes the trade, reserves the offer and tells the board to forget the draft" do
    sign_in @alice

    post trades_path(locale: :fr), params: { friend: @bob.token, give: { "portal--s1" => "2" }, take: { "blue-depths--s1" => "1" } }

    trade = Game::Trade.sole
    assert_redirected_to trade_path(token: trade.token, locale: :fr)
    assert_equal [ @alice.id, @bob.id ], [ trade.proposer_id, trade.recipient_id ]
    assert_equal({ "offer" => [ [ @portal, 2 ] ], "request" => [ [ @depths, 1 ] ] },
      trade.items.group_by(&:side).transform_values { |items| items.map { [ it.card_season_id, it.quantity ] } })
    assert_equal 2, holding(@alice, @portal).reserved
    follow_redirect!
    assert_select ".toast", /Proposition envoyée.*Lea a 7 jours pour répondre\./m
    assert_select ".trade-chip--accent", "En attente"
    assert_select ".trade-board[data-trade-board-forget-value=?]", "#{@alice.token}:#{@bob.token}"
    assert_select ".trade-side--own .trade-card__reserved", "2 réservées"
  end

  test "a draft refused goes back to the draft with the reason; one to a stranger to the list" do
    sign_in @alice

    post trades_path(locale: :fr), params: { friend: @bob.token, take: { "blue-depths--s1" => "1" } }
    assert_redirected_to new_trade_path(locale: :fr, friend: @bob.token)
    follow_redirect!
    assert_select ".trade-board__error[role=alert]", I18n.t("errors.game.invalid_offer", locale: :fr)
    assert_equal I18n.t("errors.game.invalid_offer", locale: :fr), island_props.fetch("error")

    post trades_path(locale: :fr), params: { friend: @bob.token, give: { "portal--s1" => "9" }, take: { "blue-depths--s1" => "1" } }
    follow_redirect!
    assert_select ".toast--alert", /Exemplaires insuffisants/

    post trades_path(locale: :fr), params: { friend: "1" * 24, give: { "portal--s1" => "1" }, take: { "blue-depths--s1" => "1" } }
    assert_redirected_to trades_path(locale: :fr)
    assert_equal I18n.t("errors.game.not_friends", locale: :fr), flash[:alert]
    assert_equal 0, Game::Trade.count
  end

  test "someone else's trade, or an unknown token, is not found" do
    befriend(@bob, @carol)
    trade = propose(@bob, @carol, offer: { @depths => 1 }, request: { @depths => 1 })
    sign_in @alice

    get trade_path(token: trade.token, locale: :fr)
    assert_response :not_found
    post accept_trade_path(token: "1" * 24, locale: :fr)
    assert_response :not_found
  end

  test "the screen reads in English" do
    trade = from_lea
    sign_in @alice, origin: "/en"

    get trade_path(token: trade.token, locale: :en)

    assert_select ".trades__group", "Waiting for you"
    assert_select ".trade-row__what", "Blue Depths for Portal ×2"
    assert_select ".trade-board__title", "Trade with Lea"
    assert_select ".trade-board__message", "Lea proposes this trade to you."
    assert_select ".trade-board__expiry", /Expires in\s+7 d/
    assert_select "form button", "Accept"
    assert_select "a", "Counter"
    assert_select "form button", "Decline"
  end

  test "a partner who deletes their account closes the trades with them: shown closed, the player's copies released" do
    yours = from_lea
    theirs = propose(@alice, @carol, offer: { @soldier => 1 }, request: { @depths => 1 })
    assert_equal 1, holding(@alice, @soldier).reserved
    Accounts::DeletePlayer.new.call(player: @bob).value!
    Accounts::DeletePlayer.new.call(player: @carol).value!
    sign_in @alice

    get trades_path(locale: :fr)
    assert_response :success
    assert_select ".trades__group", "Terminés récemment"
    assert_select ".trade-row", 2
    assert_select ".trade-row__name", /Officier sans nom/
    assert_select ".trade-row .trade-chip--muted", text: "Clos", count: 2
    assert_select ".trade-row__when", /annulé/
    assert_select ".tab-bar__badge", 0
    assert_equal 0, holding(@alice, @soldier).reserved

    [ yours, theirs ].each do |trade|
      get trade_path(token: trade.token, locale: :fr)
      assert_response :success
      assert_select ".trade-board__title", "Échange avec Officier sans nom"
      assert_select ".trade-board__message", "Échange clos."
      assert_select ".trade-board__actions form, .trade-board__actions a", 0
    end
    get counter_trade_path(token: yours.token, locale: :fr)
    assert_redirected_to trade_path(token: yours.token, locale: :fr)
  end

  test "a player with no trade sees the empty line, pointing to the invite panel" do
    sign_in @alice

    get trades_path(locale: :fr)

    assert_select ".trades__empty", /Aucun échange pour l'instant\./ do
      assert_select "a[href=?]", friends_path(locale: :fr, anchor: "friends-invite"), "Invitez un ami pour échanger des cartes."
    end
    assert_select ".trade-board", 0
  end

  test "a side of the counter form with no copy left to place says so and why" do
    trade = from_lea
    holding(@alice, @portal).update!(reserved: 3)
    holding(@bob, @depths).update!(quantity: 0, reserved: 0)
    sign_in @alice

    get counter_trade_path(token: trade.token, locale: :fr)

    assert_response :success
    assert_select ".trade-side--own .trade-side__none", "Aucune carte disponible. Vos exemplaires sont tous réservés dans d'autres échanges."
    assert_select ".trade-side--friend .trade-side__none", "Aucune carte disponible. Lea n'a plus aucune de ces cartes."

    holding(@alice, @portal).update!(quantity: 0, reserved: 0)
    get counter_trade_path(token: trade.token, locale: :fr)
    assert_select ".trade-side--own .trade-side__none", "Aucune carte disponible. Vous n'avez plus aucune de ces cartes."
  end

  test "a counter form whose sides have copies to place shows no such line" do
    trade = from_lea
    sign_in @alice

    get counter_trade_path(token: trade.token, locale: :fr)

    assert_select ".trade-side__none", 0
    get trade_path(token: trade.token, locale: :fr)
    assert_select ".trade-side__none", 0
  end

  test "the answers are limited to 20 a minute" do
    trade = from_lea
    sign_in @alice

    with_counting_rate_limit(TradesController) do
      21.times { post decline_trade_path(token: trade.token, locale: :fr) }
    end

    assert_redirected_to trades_path(locale: :fr)
    assert_equal I18n.t("trades.throttled", locale: :fr), flash[:alert]
  end

  test "sending drafts is limited with the answers" do
    sign_in @alice

    with_counting_rate_limit(TradesController) do
      21.times { post trades_path(locale: :fr), params: { friend: @bob.token } }
    end

    assert_redirected_to trades_path(locale: :fr)
    assert_equal I18n.t("trades.throttled", locale: :fr), flash[:alert]
  end
end
