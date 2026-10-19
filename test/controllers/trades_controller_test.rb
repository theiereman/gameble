require "test_helper"
require_relative "../support/counting_rate_limit"
require_relative "../support/steam_sign_in"

class TradesControllerTest < ActionDispatch::IntegrationTest
  include CountingRateLimit
  include SteamSignIn

  def sign_in_origin = "/fr"

  setup do
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

  def befriend(first, second)
    low, high = [ first.id, second.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
  end

  def hold(player, card_season_id, quantity)
    Game::Holding.create!(player_id: player.id, card_season_id:, quantity:, reserved: 0)
  end

  def holding(player, card_season_id) = Game::Holding.find_by(player_id: player.id, card_season_id:)

  def revision(trade) = { revision: Game::Trade.find(trade.id).revision }

  def propose(player, recipient, offer:, request:)
    Game::ProposeTrade.new.call(player:, recipient:, offer:, request:).value!
  end

  def from_lea = propose(@bob, @alice, offer: { @depths => 1 }, request: { @portal => 2 })

  def open_from_lea = propose(@bob, @alice, offer: {}, request: { @portal => 1 })

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
      assert_select "form[action=?] input[type=hidden][name=revision][value=?]", accept_trade_path(token: trade.token, locale: :fr), revision(trade)[:revision]
      assert_select "form[action=?] input[type=hidden][name=revision][value=?]", decline_trade_path(token: trade.token, locale: :fr), revision(trade)[:revision]
      assert_select "a[href=?]", counter_trade_path(token: trade.token, locale: :fr), "Contre-proposer"
      assert_select "form[action=?] button", decline_trade_path(token: trade.token, locale: :fr), "Refuser"
    end
    assert_no_match(/trade[_-]id|\svalue="#{trade.id}"/, response.body)
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

    post accept_trade_path(token: trade.token, locale: :fr), params: revision(trade)
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

    post accept_trade_path(token: trade.token, locale: :fr), params: revision(trade)
    follow_redirect!

    message = I18n.t("errors.game.requested_cards_unavailable", locale: :fr)
    assert_select ".trade-board__error[role=alert]", message
    assert_select ".toast--alert", /Exemplaires insuffisants/
    assert_select ".trade-chip--alert", "À vous"
    assert trade.reload.open?
  end

  test "an answer to terms countered since the board was shown is refused with the current board; nothing moves" do
    trade = from_lea
    shown = revision(trade)
    travel(1.minute) { Game::CounterTrade.new.call(player: @alice, trade_id: trade.id, **revision(trade), offer: { @portal => 1 }, request: { @depths => 1 }).value! }
    travel(2.minutes) { Game::CounterTrade.new.call(player: @bob, trade_id: trade.id, **revision(trade), offer: { @depths => 2 }, request: { @portal => 1 }).value! }
    sign_in @alice

    [ accept_trade_path(token: trade.token, locale: :fr), decline_trade_path(token: trade.token, locale: :fr) ].each do |path|
      post path, params: shown
      assert_redirected_to trade_path(token: trade.token, locale: :fr)
      follow_redirect!

      assert_select ".trade-board__error[role=alert]", I18n.t("errors.game.trade_changed", locale: :fr)
      assert_select ".trade-chip--alert", "À vous"
      assert_select ".trade-side--friend .trade-card__quantity", /×2/
      assert_select "form[action=?] input[name=revision][value=?]", accept_trade_path(token: trade.token, locale: :fr), revision(trade)[:revision]
    end
    assert trade.reload.open?
    assert_equal [ 3, 0 ], [ holding(@alice, @portal).quantity, holding(@alice, @portal).reserved ]
  end

  test "an answer without the version shown is refused" do
    trade = from_lea
    sign_in @alice

    post accept_trade_path(token: trade.token, locale: :fr)
    assert_equal I18n.t("errors.game.trade_changed", locale: :fr), flash[:alert]
    post decline_trade_path(token: trade.token, locale: :fr)
    assert_equal I18n.t("errors.game.trade_changed", locale: :fr), flash[:alert]
    post counter_trade_path(token: trade.token, locale: :fr), params: { give: { "portal--s1" => "1" }, take: { "blue-depths--s1" => "1" } }
    assert_equal I18n.t("errors.game.trade_changed", locale: :fr), flash[:alert]
    assert trade.reload.open?
    assert_equal @bob.id, trade.proposer_id
  end

  def counter_form_revision
    css_select("form#trade-counter-form input[type=hidden][name=revision]").sole["value"]
  end

  test "a counter from a tab showing terms the friend has since changed is refused on the board's new terms; one from the fresh board goes through" do
    trade = from_lea
    sign_in @alice
    get trade_path(token: trade.token, locale: :fr)
    stale_tab = counter_form_revision
    travel(1.minute) do
      post counter_trade_path(token: trade.token, locale: :fr),
        params: { revision: stale_tab, give: { "portal--s1" => "1" }, take: { "blue-depths--s1" => "1" } }
    end
    travel(2.minutes) { Game::CounterTrade.new.call(player: @bob, trade_id: trade.id, **revision(trade), offer: { @depths => 2 }, request: { @portal => 1 }).value! }
    lea_terms = trade.items.reload.map { [ it.side, it.card_season_id, it.quantity ] }.sort

    travel(3.minutes) do
      post counter_trade_path(token: trade.token, locale: :fr),
        params: { revision: stale_tab, give: { "portal--s1" => "3" }, take: { "blue-depths--s1" => "1" } }
    end
    assert_redirected_to trade_path(token: trade.token, locale: :fr)
    follow_redirect!

    assert_select ".trade-board__error[role=alert]", I18n.t("errors.game.trade_changed", locale: :fr)
    assert_select ".trade-chip--alert", "À vous"
    assert_select ".trade-side--friend .trade-card__quantity", /×2/
    assert_equal revision(trade)[:revision], counter_form_revision
    trade.reload
    assert_equal [ @bob.id, lea_terms ], [ trade.proposer_id, trade.items.map { [ it.side, it.card_season_id, it.quantity ] }.sort ]
    assert_equal [ 0, 2 ], [ holding(@alice, @portal).reserved, holding(@bob, @depths).reserved ]

    travel(4.minutes) do
      post counter_trade_path(token: trade.token, locale: :fr),
        params: { revision: counter_form_revision, give: { "portal--s1" => "3" }, take: { "blue-depths--s1" => "1" } }
    end
    assert_redirected_to trade_path(token: trade.token, locale: :fr)
    assert_equal @alice.id, trade.reload.proposer_id
    assert_equal [ 3, 0 ], [ holding(@alice, @portal).reserved, holding(@bob, @depths).reserved ]
  end

  test "proposing again to a friend whose trade expired but is not yet swept closes it and sends the new proposal" do
    expired = propose(@alice, @bob, offer: { @portal => 3 }, request: { @depths => 1 })
    sign_in @alice

    travel_to(expired.expires_at + 1.second) do
      get new_trade_path(locale: :fr, friend: @bob.token)
      assert_response :success
      post trades_path(locale: :fr), params: { friend: @bob.token, give: { "portal--s1" => "3" }, take: { "blue-depths--s1" => "1" } }
    end

    fresh = Game::Trade.order(:id).last
    assert_redirected_to trade_path(token: fresh.token, locale: :fr)
    assert_equal "expired", expired.reload.status
    assert_equal [ "open", 3 ], [ fresh.status, holding(@alice, @portal).reserved ]
    assert_equal 1, Game::Trade.in_progress.count
  end

  test "asking for more copies than the friend holds is refused and nothing is reserved" do
    sign_in @alice

    post trades_path(locale: :fr), params: { friend: @bob.token, give: { "portal--s1" => "1" }, take: { "blue-depths--s1" => "3" } }
    follow_redirect!

    assert_select ".trade-board__error[role=alert]", I18n.t("errors.game.request_exceeds_holdings", locale: :fr)
    assert_equal 0, Game::Trade.count
    assert_equal 0, holding(@alice, @portal).reserved
  end

  test "declining tells the friend's name" do
    trade = from_lea
    sign_in @alice

    post decline_trade_path(token: trade.token, locale: :fr), params: revision(trade)
    follow_redirect!

    assert_select ".toast", /Échange refusé.*Votre réponse a été envoyée à Lea\./m
    assert_select ".trade-board__expiry", /refusé à l'instant/
    assert_equal "declined", trade.reload.status
  end

  test "a closed trade offers a new one with the friend, while they are still friends" do
    trade = from_lea
    sign_in @alice
    post decline_trade_path(token: trade.token, locale: :fr), params: revision(trade)

    get trade_path(token: trade.token, locale: :fr)
    assert_select ".trade-board__actions a.button--primary[href=?]", new_trade_path(locale: :fr, friend: @bob.token), "Nouvel échange avec Lea"

    Game::Friendship.delete_all
    get trade_path(token: trade.token, locale: :fr)
    assert_select ".trade-board__actions a", 0
  end

  test "a closed trade with a private friend, or while private, shows why trades are closed instead" do
    trade = from_lea
    sign_in @alice
    post decline_trade_path(token: trade.token, locale: :fr), params: revision(trade)

    @bob.update_columns(visibility: "private")
    get trade_path(token: trade.token, locale: :fr)
    assert_select ".trade-board__actions a.button", 0
    assert_select ".trade-board__actions .trades-closed", "Le profil de Lea est privé : échanges fermés."

    @bob.update_columns(visibility: "friends_only")
    get trade_path(token: trade.token, locale: :fr)
    assert_select ".trade-board__actions a.button--primary", "Nouvel échange avec Lea"

    @alice.update_columns(visibility: "private")
    get trade_path(token: trade.token, locale: :fr)
    assert_select ".trade-board__actions a.button", 0
    assert_select ".trade-board__actions .trades-closed", /Votre profil est privé : les échanges sont fermés\./
    assert_select ".trade-board__actions .trades-closed a[href=?]", settings_path(locale: :fr), "RÉGLAGES"
  end

  test "accepting or countering a trade whose proposer went private moves nothing and names them" do
    trade = from_lea
    sign_in @alice
    @bob.update_columns(visibility: "private")

    post accept_trade_path(token: trade.token, locale: :fr), params: revision(trade)
    follow_redirect!
    assert_select ".toast--alert", /Le profil de Lea est privé : échanges fermés\./
    assert_equal "open", trade.reload.status

    post counter_trade_path(token: trade.token, locale: :fr), params: { **revision(trade), give: { "portal--s1" => "1" }, take: { "blue-depths--s1" => "1" } }
    follow_redirect!
    assert_select ".toast--alert", /Le profil de Lea est privé : échanges fermés\./
    assert_equal "open", trade.reload.status
    assert_equal 2, holding(@bob, @depths).quantity
  end

  test "the counter form edits both sides' quantities and sends the counter-proposal" do
    trade = from_lea
    sign_in @alice

    get counter_trade_path(token: trade.token, locale: :fr)
    assert_response :success
    assert_select ".trade-board--editing form[action=?][method=post] input[type=hidden][name=revision][value=?]",
      counter_trade_path(token: trade.token, locale: :fr), revision(trade)[:revision]
    assert_select ".trade-side--editing", 2
    assert_select ".trade-board__message", "Modifiez ce que vous donnez et ce que vous demandez, puis renvoyez."
    assert_select "input[name='give[portal--s1]'][value='2'][min='0'][max='3']"
    assert_select "input[name='take[blue-depths--s1]'][value='1'][max='2']"
    assert_select "button[type=submit]", "Renvoyer la contre-proposition"
    assert_select "a[href=?]", trade_path(token: trade.token, locale: :fr), "Annuler les modifications"

    round = "#{@alice.token}:#{trade.token}:#{trade.expires_at.to_i}"
    post counter_trade_path(token: trade.token, locale: :fr), params: { **revision(trade), give: { "portal--s1" => "1" }, take: { "blue-depths--s1" => "2" } }
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

  test "a counter that empties the friend's side is refused on its form" do
    trade = from_lea
    sign_in @alice

    post counter_trade_path(token: trade.token, locale: :fr), params: { **revision(trade), give: { "portal--s1" => "1" }, take: { "blue-depths--s1" => "0" } }

    assert_redirected_to counter_trade_path(token: trade.token, locale: :fr)
    follow_redirect!
    assert_select ".trade-board__error", I18n.t("errors.game.invalid_request", locale: :fr)
    assert_equal @bob.id, trade.reload.proposer_id
  end

  test "a counter that empties the player's own side is sent as an open request, reserving nothing" do
    trade = from_lea
    sign_in @alice

    post counter_trade_path(token: trade.token, locale: :fr), params: { **revision(trade), give: { "portal--s1" => "0" }, take: { "blue-depths--s1" => "1" } }

    assert_redirected_to trade_path(token: trade.token, locale: :fr)
    follow_redirect!
    assert_select ".toast", /Proposition envoyée.*Lea a 7 jours pour choisir ce qui lui plaît en retour\./m
    assert_select ".trade-side--own .trade-side__open", "À choisir par Lea"
    assert_equal @alice.id, trade.reload.proposer_id
    assert_equal [ "request" ], trade.items.map(&:side)
    assert_equal 0, holding(@alice, @portal).reserved
    assert_equal 0, holding(@bob, @depths).reserved
  end

  def island_props
    element = css_select("[data-controller='turbo-mount-trade-board']").first
    assert element, "the TradeBoard island is mounted"
    JSON.parse(element["data-turbo-mount-trade-board-props-value"])
  end

  test "the counter form mounts the trade board island with both holders' cards, over the quantity fields" do
    hold(@bob, @soldier, 3)
    trade = from_lea
    propose(@alice, @carol, offer: { @portal => 1 }, request: { @depths => 1 })
    sign_in @alice

    get counter_trade_path(token: trade.token, locale: :fr)
    assert_response :success
    assert_select ".trade-board--editing .trade-island input[name='give[portal--s1]'][max='2'][form='trade-counter-form']"
    assert_select ".trade-board__actions form#trade-counter-form[data-controller='trade-send']:not([hidden]) #trade-send-reason[hidden]",
      "Placez au moins une carte du côté de Lea."
    assert_select ".trade-board__actions [data-trade-board-target='readActions'][hidden]"

    props = island_props
    friend, own = props.fetch("sides")
    assert_equal %w[friend take], friend.values_at("side", "field")
    assert_equal %w[own give], own.values_at("side", "field")
    assert_equal "Choisir dans la collection de Lea", friend.fetch("pickerTitle")
    assert_equal "Cartes de Lea", friend.fetch("pickerTitleShort")
    assert_equal "Placer mes cartes", own.fetch("add")
    assert_equal [ nil, "Laissez ce côté vide : Lea choisira ce qui lui plaît en retour." ], [ friend.fetch("help"), own.fetch("help") ]
    assert_equal [ { "key" => "blue-depths--s1", "quantity" => 1 } ], friend.fetch("lines")
    assert_equal [ { "key" => "portal--s1", "quantity" => 2 } ], own.fetch("lines")

    assert_equal [ [ "tin-soldier--s1", 1, 0, 1, 1, 3 ], [ "portal--s1", 3, 1, 2, 3, 0 ] ],
      own.fetch("cards").map { it.values_at("key", "owned", "reserved", "max", "copies", "otherCopies") }
    assert_equal [ [ "tin-soldier--s1", 3, 0, 3, 3, 1 ], [ "blue-depths--s1", 2, 0, 2, 2, 0 ] ],
      friend.fetch("cards").map { it.values_at("key", "owned", "reserved", "max", "copies", "otherCopies") }
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
    assert_equal({ "zero" => "0 carte", "one" => "%{count} carte", "other" => "%{count} cartes" }, props.dig("strings", "cards"))
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
      params: { **revision(trade), give: { "portal--s1" => "1", "tin-soldier--s1" => "1" }, take: { "tin-soldier--s1" => "2" } }

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

    post counter_trade_path(token: trade.token, locale: :fr), params: { **revision(trade), give: { "blue-depths--s1" => "1" }, take: { "blue-depths--s1" => "1" } }
    assert_redirected_to counter_trade_path(token: trade.token, locale: :fr)
    follow_redirect!
    assert_select ".trade-board__error", I18n.t("errors.game.invalid_offer", locale: :fr)
    assert_equal I18n.t("errors.game.invalid_offer", locale: :fr), island_props.fetch("error")

    post counter_trade_path(token: trade.token, locale: :fr), params: { **revision(trade), give: { "portal--s1" => "1" }, take: { "golden-crown--s1" => "1" } }
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

    post counter_trade_path(token: trade.token, locale: :fr), params: { **revision(trade), give: { "portal--s1" => "1" }, take: { "blue-depths--s1" => "1" } }
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
      assert_select ".trade-side__count", { count: 2, text: "0 carte" }
      assert_select ".trade-board__message", "Choisissez les cartes de chaque côté."
      assert_select ".trade-side--own .trade-side__help", "Laissez ce côté vide : Lea choisira ce qui lui plaît en retour."
      assert_select ".trade-side--friend .trade-side__help", 0
      assert_select "#trade-send-reason", "Placez au moins une carte du côté de Lea."
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
    assert_equal [ nil, "Laissez ce côté vide : Lea choisira ce qui lui plaît en retour." ], [ friend.fetch("help"), own.fetch("help") ]
    assert_equal [ "blue-depths--s1" ], friend.fetch("cards").map { it.fetch("key") }
    assert_equal [ [ "tin-soldier--s1", 0 ], [ "portal--s1", 3 ] ], own.fetch("cards").map { it.values_at("key", "max") }
  end

  def second_edition(card_season_id)
    season = Catalog::Season.find_by(number: 2) || Catalog::Season.create!(status: :published, number: 2, published_at: Time.current)
    one = Catalog::CardSeason.find(card_season_id)
    Catalog::CardSeason.insert_all!([ { card_id: one.card_id, season_id: season.id, prestige_score: one.prestige_score, rating: one.rating,
      rarity: one.rarity, number: one.number } ], returning: :id).rows.flatten.sole
  end

  test "each card of a draft carries both players' copies of its game, over every edition" do
    hold(@bob, @soldier, 1)
    hold(@bob, second_edition(@soldier), 1)
    hold(@bob, second_edition(@portal), 1)
    sign_in @alice

    get new_trade_path(locale: :fr, friend: @bob.token)

    props = island_props
    friend, own = props.fetch("sides")
    assert_equal [ [ "tin-soldier--s1", 1, 2, 1 ], [ "blue-depths--s1", 2, 2, 0 ], [ "tin-soldier--s2", 1, 2, 1 ], [ "portal--s2", 1, 1, 3 ] ],
      friend.fetch("cards").map { it.values_at("key", "owned", "copies", "otherCopies") }
    assert_equal [ [ "tin-soldier--s1", 1, 1, 2 ], [ "portal--s1", 3, 3, 1 ] ],
      own.fetch("cards").map { it.values_at("key", "owned", "copies", "otherCopies") }
    assert_equal({ "duplicates" => "Ses doublons", "missing" => "Absentes de ma collection", "shared" => "En commun" },
      props.dig("strings", "chips", "friend"))
    assert_equal({ "duplicates" => "Mes doublons", "missing" => "Absentes de sa collection", "available" => "Disponibles" },
      props.dig("strings", "chips", "own"))
    assert_equal "Collections", props.dig("strings", "compareLegend")
    assert_equal [ "Filtres", "Filtres actifs :" ], props.fetch("strings").values_at("filtersTitle", "filtersActive")
    assert_match(/\A<svg [^>]*class="pixel-icon filters__chevron"/, props.fetch("chevronIcon"))
    assert_no_match(/"id"|card_season_id/, props.to_json)
  end

  test "a draft is only for a friend the player may trade with" do
    sign_in @alice

    get new_trade_path(locale: :fr, friend: @alice.token)
    assert_response :not_found
    get new_trade_path(locale: :fr, friend: "1" * 24)
    assert_response :not_found
    get new_trade_path(locale: :fr, friend: "")
    assert_response :not_found
    befriend(@alice, accounts_players(:banned))
    get new_trade_path(locale: :fr, friend: accounts_players(:banned).token)
    assert_response :not_found
    Game::Friendship.where(low_player_id: [ @alice.id, @carol.id ].min).delete_all
    get new_trade_path(locale: :fr, friend: @carol.token)
    assert_response :not_found
  end

  test "a new trade without a friend opens the chooser beside the list, one row per friend leading to the draft" do
    sign_in @alice

    get new_trade_path(locale: :fr)

    assert_response :success
    assert_select "title", /Nouvel échange/
    assert_select ".trades--board .trades__list"
    assert_select ".top-bar__phone-back[href=?]", trades_path(locale: :fr)
    assert_select ".trade-board", 0
    assert_select "section.trade-chooser.panel--brackets[aria-labelledby=trade-chooser-heading]" do
      assert_select "h2#trade-chooser-heading", "Nouvel échange"
      assert_select ".trade-chooser__line", "Choisissez l'ami avec qui échanger."
      assert_select "ul.trade-chooser__friends[aria-label=?] li.trade-chooser__friend", "Vos amis", 2
    end
    { @bob => "Lea", @carol => "Max" }.each do |friend, name|
      row = css_select(".trade-chooser__friend").find { it.at_css(".trade-chooser__name").text == name }
      assert row.at_css(".friends__presence"), "#{name}'s row shows their presence"
      link = row.at_css("a.button")
      assert_equal new_trade_path(friend: friend.token, locale: :fr), link["href"]
      assert_equal "Échange avec #{name}", link["aria-label"]
      assert_equal "Échanger", link.text.strip
    end

    get css_select(".trade-chooser__friend a.button").first["href"]
    assert_response :success
    assert_select ".trade-board--editing .trade-board__title", /Échange avec (Lea|Max)/
  end

  test "the chooser shows a private friend's closed line instead of the trade button" do
    sign_in @alice
    @bob.update_columns(visibility: "private")

    get new_trade_path(locale: :fr)

    lea, max = %w[Lea Max].map { |name| css_select(".trade-chooser__friend").find { it.at_css(".trade-chooser__name").text == name } }
    assert_equal "Profil privé", lea.at_css(".friends__presence--private").text.strip
    assert_equal "Le profil de Lea est privé : échanges fermés.", lea.at_css(".trades-closed").text.strip
    assert_nil lea.at_css("a.button")
    assert_equal new_trade_path(friend: @carol.token, locale: :fr), max.at_css("a.button")["href"]
  end

  test "the chooser of a private player shows the own-private closed line with its settings link on every row" do
    sign_in @alice
    @alice.update_columns(visibility: "private")

    get new_trade_path(locale: :fr)

    assert_select ".trade-chooser__friend", 2
    assert_select ".trade-chooser__friend a.button", 0
    assert_select ".trade-chooser__friend .trades-closed", text: /Votre profil est privé : les échanges sont fermés\./, count: 2
    assert_select ".trade-chooser__friend .trades-closed a[href=?]", settings_path(locale: :fr), text: "RÉGLAGES", count: 2
  end

  test "the chooser leads a friend already trading to that trade, one at a time" do
    trade = from_lea
    sign_in @alice

    get new_trade_path(locale: :fr)
    lea = css_select(".trade-chooser__friend").find { it.at_css(".trade-chooser__name").text == "Lea" }
    assert_equal new_trade_path(friend: @bob.token, locale: :fr), lea.at_css("a.button")["href"]

    get lea.at_css("a.button")["href"]
    assert_redirected_to trade_path(token: trade.token, locale: :fr)
    follow_redirect!
    assert_select ".toast--alert", /Un échange à la fois/
  end

  test "the chooser of a player without friends points to the invite panel" do
    Game::Friendship.delete_all
    sign_in @alice

    get new_trade_path(locale: :fr)

    assert_response :success
    assert_select ".trade-chooser__friend", 0
    assert_select ".trade-chooser__empty", /Aucun ami pour l'instant\./ do
      assert_select "a[href=?]", friends_path(locale: :fr, anchor: "friends-invite"), "Invitez-en un avec votre lien ou votre code."
    end
  end

  test "the list opens a new trade, with and without trades" do
    sign_in @alice

    get trades_path(locale: :fr)
    assert_select ".trades__list > .trades__new:first-child a.button[href=?]", new_trade_path(locale: :fr), "Nouvel échange"
    assert_select ".trades__list > .trades__new + .trades__empty"

    from_lea
    get trades_path(locale: :fr)
    assert_select ".trades__list > .trades__new:first-child a.button[href=?]", new_trade_path(locale: :fr), "Nouvel échange"
    assert_select ".trades__list > .trades__new + .trades__group"
  end

  test "the chooser reads in English" do
    sign_in @alice, origin: "/en"

    get new_trade_path(locale: :en)

    assert_select ".trades__new a", "New trade"
    assert_select "#trade-chooser-heading", "New trade"
    assert_select ".trade-chooser__line", "Choose the friend to trade with."
    assert_select "ul.trade-chooser__friends[aria-label=?]", "Your friends"
    assert_select ".trade-chooser__friend a.button[aria-label=?]", "Trade with Lea", "Trade"

    Game::Friendship.delete_all
    get new_trade_path(locale: :en)
    assert_select ".trade-chooser__empty", /No friends yet\./ do
      assert_select "a", "Invite one with your link or your code."
    end
  end

  test "a draft for a private friend, or while private, goes back to the list with the reason" do
    sign_in @alice
    @bob.update_columns(visibility: "private")

    get new_trade_path(locale: :fr, friend: @bob.token)
    assert_redirected_to trades_path(locale: :fr)
    follow_redirect!
    assert_select ".toast--alert", /Le profil de Lea est privé : échanges fermés\./

    @bob.update_columns(visibility: "public")
    @alice.update_columns(visibility: "private")
    get new_trade_path(locale: :fr, friend: @bob.token)
    assert_redirected_to trades_path(locale: :fr)
    follow_redirect!
    assert_select ".toast--alert", /Votre profil est privé : les échanges sont fermés\./
  end

  test "a forged proposal to a private friend, or from a private player, is refused and reserves nothing" do
    sign_in @alice
    @bob.update_columns(visibility: "private")
    params = { friend: @bob.token, give: { "portal--s1" => "1" }, take: { "blue-depths--s1" => "1" } }

    post trades_path(locale: :fr), params: params
    assert_redirected_to trades_path(locale: :fr)
    follow_redirect!
    assert_select ".toast--alert", /Le profil de Lea est privé : échanges fermés\./

    @bob.update_columns(visibility: "public")
    @alice.update_columns(visibility: "private")
    post trades_path(locale: :fr), params: params
    assert_redirected_to trades_path(locale: :fr)
    follow_redirect!
    assert_select ".toast--alert", /Votre profil est privé : les échanges sont fermés\./
    assert_equal 0, Game::Trade.count
    assert_equal 0, holding(@alice, @portal).reserved
  end

  test "a visitor asking for a draft is sent home to sign in" do
    get new_trade_path(locale: :fr)
    assert_redirected_to home_path(locale: :fr)
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

  test "sending a draft with only the friend's side proposes an open request: nothing reserved, left for the friend to choose" do
    sign_in @alice

    post trades_path(locale: :fr), params: { friend: @bob.token, take: { "blue-depths--s1" => "1" } }

    trade = Game::Trade.sole
    assert_redirected_to trade_path(token: trade.token, locale: :fr)
    assert_equal [ "request" ], trade.items.map(&:side)
    assert_equal [ 0, 0 ], [ holding(@alice, @portal).reserved, holding(@alice, @soldier).reserved ]
    follow_redirect!
    assert_select ".toast", /Proposition envoyée.*Lea a 7 jours pour choisir ce qui lui plaît en retour\./m
    assert_select ".trade-chip--accent", "En attente"
    assert_select ".trade-side--own" do
      assert_select ".trade-side__open", "À choisir par Lea"
      assert_select ".trade-side__count", 0
      assert_select ".trade-card", 0
    end
    assert_select ".trade-card__reserved", 0
    assert_select ".trade-row__what", "Profondeurs bleues contre À choisir"
  end

  test "an open request waiting for the player offers no acceptance but invites to choose, then counter or decline" do
    trade = open_from_lea
    sign_in @alice

    get trade_path(token: trade.token, locale: :fr)

    assert_select ".trade-row__what", "À choisir contre Portal"
    assert_select ".trade-board" do
      assert_select ".trade-side--friend .trade-side__open", "À vous de choisir"
      assert_select ".trade-side--friend .trade-side__count", 0
      assert_select ".trade-side--own .trade-side__count", "1 carte"
      assert_select "form[action=?]", accept_trade_path(token: trade.token, locale: :fr), 0
      assert_select "[data-trade-board-target='readActions']" do
        assert_select ".trade-board__open", "Lea vous laisse choisir. Prenez ce que vous voulez dans sa collection, puis renvoyez."
        assert_select "a[href=?]", counter_trade_path(token: trade.token, locale: :fr), "Contre-proposer"
        assert_select "form[action=?] button", decline_trade_path(token: trade.token, locale: :fr), "Refuser"
      end
    end
    friend, = island_props.fetch("sides")
    assert_includes friend.fetch("readHtml"), "À vous de choisir"
  end

  test "accepting an open request is refused with the reason on the board, and nothing moves" do
    trade = open_from_lea
    sign_in @alice

    post accept_trade_path(token: trade.token, locale: :fr), params: revision(trade)
    follow_redirect!

    message = "Rien à recevoir pour l'instant : choisissez ce que vous voulez dans la collection de Lea, puis renvoyez."
    assert_select ".trade-board__error[role=alert]", message
    assert_select ".toast--alert", /#{Regexp.escape(message)}/
    assert trade.reload.open?
    assert_equal [ 3, 0 ], [ holding(@alice, @portal).quantity, holding(@alice, @portal).reserved ]
    assert_not Game::FeedEntry.exists?
  end

  test "a declined open request is shown closed, without a side left to choose" do
    trade = open_from_lea
    sign_in @alice

    post decline_trade_path(token: trade.token, locale: :fr), params: revision(trade)
    follow_redirect!

    assert_select ".trade-chip--muted", "Clos"
    assert_select ".trade-side__open", 0
    assert_select ".trade-side--friend .trade-side__count", "0 carte"
    assert_no_match(/À vous de choisir|À choisir par/, response.body)
  end

  test "cancelling an open request says the friend has nothing left to choose" do
    trade = propose(@alice, @bob, offer: {}, request: { @depths => 1 })
    sign_in @alice

    post cancel_trade_path(token: trade.token, locale: :fr)
    follow_redirect!

    assert_select ".toast", /Proposition annulée.*Lea n'a plus rien à choisir\./m
    assert_select ".trade-side__open", 0
    assert_no_match(/Vos cartes ne sont plus réservées/, response.body)
  end

  test "answering an open request with a card of the friend's sends it back, reserving the player's offer" do
    trade = open_from_lea
    sign_in @alice

    post counter_trade_path(token: trade.token, locale: :fr), params: { **revision(trade), give: { "portal--s1" => "1" }, take: { "blue-depths--s1" => "1" } }

    assert_redirected_to trade_path(token: trade.token, locale: :fr)
    follow_redirect!
    assert_select ".toast", /Proposition envoyée.*Lea a 7 jours pour répondre\./m
    assert_equal 1, holding(@alice, @portal).reserved
    assert_equal @alice.id, trade.reload.proposer_id
  end

  test "a draft refused goes back to the draft with the reason; one to a stranger to the list" do
    sign_in @alice

    post trades_path(locale: :fr), params: { friend: @bob.token, give: { "portal--s1" => "1" } }
    assert_redirected_to new_trade_path(locale: :fr, friend: @bob.token)
    follow_redirect!
    assert_select ".trade-board__error[role=alert]", I18n.t("errors.game.invalid_request", locale: :fr)
    assert_equal I18n.t("errors.game.invalid_request", locale: :fr), island_props.fetch("error")

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
    assert_select ".trade-row__name", /Joueur sans nom/
    assert_select ".trade-row .trade-chip--muted", text: "Clos", count: 2
    assert_select ".trade-row__when", /annulé/
    assert_select ".tab-bar__badge", 0
    assert_equal 0, holding(@alice, @soldier).reserved

    [ yours, theirs ].each do |trade|
      get trade_path(token: trade.token, locale: :fr)
      assert_response :success
      assert_select ".trade-board__title", "Échange avec Joueur sans nom"
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
      21.times { post decline_trade_path(token: trade.token, locale: :fr), params: revision(trade) }
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
