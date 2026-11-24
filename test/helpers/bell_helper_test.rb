require "test_helper"

class BellHelperTest < ActionView::TestCase
  include DuelsHelper

  setup { controller.request.path_parameters[:locale] = "en" }

  def text_of(sentence) = Nokogiri::HTML.fragment(sentence).text

  def subject_of(card: nil, partner_card: nil, set: nil)
    bell_reaction_subject(Game::BellItems::ReactionSubject.new(card:, partner_card:, set:))
  end

  def market_notice(kind: :outbid, other: accounts_players(:administrator), amount: 30_000, at: Time.utc(2026, 11, 10, 12, 0, 0))
    Game::Market::MarketNotices::Line.new(kind:, token: "tok", card: "Portal", other:, amount:, noticed_at: at)
  end

  test "a reaction line names the card, both cards of a trade, or the set the entry shows, in both languages" do
    assert_equal "Portal", subject_of(card: "Portal")
    assert_equal "Valve", subject_of(set: catalog_sets(:valve_one))
    assert_equal "Portal for Hades", subject_of(card: "Portal", partner_card: "Hades")
    I18n.with_locale(:fr) { assert_equal "Portal contre Hades", subject_of(card: "Portal", partner_card: "Hades") }
  end

  test "a reaction line whose card left the catalog names nothing" do
    assert_nil subject_of
  end

  test "an outbid line names the other player without a link, leads to the Annonce and clears with its target" do
    accounts_players(:administrator).update_columns(persona_name: "Max")

    line = bell_market_line(market_notice)

    assert_equal market_listing_path(token: "tok"), line.path
    assert_equal line.path, line.href
    assert_equal "market:tok:2026-11-10T12:00:00.000000Z", line.key
    assert_includes line.sentence, "Max"
    assert_includes line.sentence, "went past your maximum on Portal."
    assert_not_includes line.sentence, "<a"
    assert_not line.lasting
  end

  test "an outbid line reads in French" do
    accounts_players(:administrator).update_columns(persona_name: "Max")

    I18n.with_locale(:fr) { assert_includes bell_market_line(market_notice).sentence, "a dépassé votre maximum sur Portal." }
  end

  test "the outcome lines lead to the Annonce for a win and to MES VENTES for a sale or no offer, in both languages" do
    accounts_players(:administrator).update_columns(persona_name: "Max")
    won = bell_market_line(market_notice(kind: :won, other: nil, amount: 26_300))
    sold = bell_market_line(market_notice(kind: :sold, other: nil, amount: 23_670))
    unsold = bell_market_line(market_notice(kind: :unsold, other: nil, amount: nil))

    assert_equal [ market_listing_path(token: "tok"), market_my_sales_path, market_my_sales_path ], [ won, sold, unsold ].map(&:path)
    assert_includes won.sentence, "You won Portal for"
    assert_includes won.sentence, "26,300"
    assert_includes sold.sentence, "Portal sold. You receive"
    assert_includes unsold.sentence, "Portal received no offers. The card is returned to you."
    I18n.with_locale(:fr) do
      assert_includes bell_market_line(market_notice(kind: :won, other: nil)).sentence, "Vous avez remporté Portal pour"
      assert_includes bell_market_line(market_notice(kind: :sold, other: nil)).sentence, "Portal s'est vendue. Vous recevez"
      assert_includes bell_market_line(market_notice(kind: :unsold, other: nil)).sentence, "Portal n'a reçu aucune offre. La carte vous est rendue."
    end
  end

  test "a voided lead leads the seller to MES VENTES in both languages" do
    line = bell_market_line(market_notice(kind: :lead_voided, other: nil, amount: nil))

    assert_equal market_my_sales_path, line.path
    assert_includes line.sentence, "The leading player on Portal was removed. The auction restarts from its starting price."
    I18n.with_locale(:fr) do
      assert_includes bell_market_line(market_notice(kind: :lead_voided, other: nil, amount: nil)).sentence, "Le joueur en tête sur Portal a été retiré."
    end
  end

  def order_notice(kind:, amount: 1_300, at: Time.utc(2026, 11, 10, 12, 0, 0))
    edition = Catalog::CardViews.call([ catalog_card_seasons(:portal_one).id ], locale: :en).values.sole
    Game::Market::OrderNoticeLines::Line.new(kind:, token: "ord", listing_token: "lst", card: "Portal", edition:, other: nil, amount:, noticed_at: at)
  end

  test "a served order leads to the edition received, in both languages" do
    line = bell_order_line(order_notice(kind: :order_served))
    edition = order_notice(kind: :order_served).edition

    assert_equal [ card_season_path(slug: edition.id, number: edition.season_number), "order:ord:2026-11-10T12:00:00.000000Z" ], [ line.href, line.key ]
    assert_equal "Your order on Portal was filled: the card joins your collection.", text_of(line.sentence)
    I18n.with_locale(:fr) do
      assert_equal "Votre ordre sur Portal est servi\u202f: la carte rejoint votre collection.", text_of(bell_order_line(order_notice(kind: :order_served)).sentence)
    end
  end

  test "an expired order leads to My orders with the amount released, and a listing above it to the Annonce, without the seller" do
    expired = bell_order_line(order_notice(kind: :order_expired))
    above = bell_order_line(order_notice(kind: :listed_above_order))

    assert_equal [ market_my_orders_path, market_listing_path(token: "lst") ], [ expired.href, above.href ]
    assert_includes text_of(expired.sentence), "Your order on Portal expired. Your"
    assert_includes text_of(above.sentence), "Portal is on sale for"
    assert_includes text_of(above.sentence), ", above your order."
    I18n.with_locale(:fr) { assert_includes text_of(bell_order_line(order_notice(kind: :listed_above_order)).sentence), "Portal est en vente à" }
  end

  test "an order turned into a bid leads to its Annonce, leading or outbid, in both languages" do
    leads = bell_order_line(order_notice(kind: :order_leads))
    beaten = bell_order_line(order_notice(kind: :order_beaten))

    assert_equal [ market_listing_path(token: "lst") ] * 2, [ leads.href, beaten.href ]
    assert_includes text_of(leads.sentence), "Your order on Portal became a bid: it leads the auction up to"
    assert_includes text_of(beaten.sentence), "Your order on Portal became a bid and was outbid."
    I18n.with_locale(:fr) do
      assert_includes text_of(bell_order_line(order_notice(kind: :order_leads)).sentence), "Votre ordre sur Portal est devenu une enchère"
      assert_includes text_of(bell_order_line(order_notice(kind: :order_beaten)).sentence), "a été dépassé"
    end
  end

  def grouped(count:, seen: false) = Game::Market::GroupedWanted::Grouped.new(count:, card: "Portal", newest_at: Time.utc(2026, 11, 10, 12), seen:)

  test "the grouped wanted line counts the cards on sale, opens the wanted market and carries its seen state" do
    line = bell_wanted_line(grouped(count: 2))

    assert_equal [ "wanted:grouped:2026-11-10T12:00:00.000000Z", market_path(wanted: "1"), false ], [ line.key, line.href, line.read ]
    assert_equal "2 cards you are looking for are on sale.", line.sentence
    assert_equal "Portal, a card you want, is on sale.", bell_wanted_line(grouped(count: 1)).sentence
    assert bell_wanted_line(grouped(count: 2, seen: true)).read
    I18n.with_locale(:fr) do
      assert_equal "2 cartes que vous cherchez sont en vente.", bell_wanted_line(grouped(count: 2)).sentence
      assert_equal "Portal, une carte que vous voulez, est en vente.", bell_wanted_line(grouped(count: 1)).sentence
    end
  end

  test "a withdrawn listing tells its leader the amount is available again and leads to the Annonce" do
    line = bell_market_line(market_notice(kind: :withdrawn, other: nil))

    assert_equal market_listing_path(token: "tok"), line.path
    assert_includes line.sentence, "Portal was withdrawn from the market. Your"
    I18n.with_locale(:fr) { assert_includes bell_market_line(market_notice(kind: :withdrawn, other: nil)).sentence, "Portal a été retirée du marché. Vos" }
  end

  test "a kind the bell does not know is left out" do
    assert_nil bell_market_line(market_notice(kind: :unknown))
  end

  test "a removed player is named anonymously" do
    removed = accounts_players(:administrator)
    removed.update_columns(deleted_at: Time.current, steam_id: nil)

    assert_includes bell_market_line(market_notice(other: removed)).sentence, I18n.t("player_name.anonymous")
  end

  test "the market slot shows the listing lines, then the order lines, then the grouped wanted line, before the daily capsule" do
    items = Game::BellItems::Result.new(trades: [], updates: [], invitations: [], reactions: [], market: [ market_notice ],
      orders: [ order_notice(kind: :order_expired) ], wanted: grouped(count: 2), daily: nil, duels: [],
      goal: Game::BellItems::GoalLine.new(week_start: Date.new(2026, 11, 9), reward_ready: false, target: 10, reached: false))

    assert_equal [ "market", "order", "wanted", "mission" ], bell_lines(items).map { it.key.split(":").first }
  end

  TOKEN = "a" * 24

  def duel_line(kind:, outcome: nil, score: 0, other_score: 0)
    Game::BellItems::DuelLine.new(token: TOKEN, opponent: accounts_players(:moderator), kind:, outcome:, score:, other_score:, ended_at: nil)
  end

  test "a duel in progress is a lasting resume line to the duel, in both languages" do
    accounts_players(:moderator).update_columns(persona_name: "Hugo")
    line = bell_duel_line(duel_line(kind: :resume))

    assert_equal [ "duel-resume:#{TOKEN}", "/en/duels/#{TOKEN}", true ], [ line.key, line.href, line.lasting ]
    assert_equal [ "Your duel against Hugo awaits your return.", "Resume" ], [ line.sentence, line.action ]
    I18n.with_locale(:fr) do
      assert_equal [ "Votre duel contre Hugo attend votre retour.", "Reprendre" ], [ bell_duel_line(duel_line(kind: :resume)).sentence, bell_duel_line(duel_line(kind: :resume)).action ]
    end
  end

  test "a finished duel is a result line with the player's score first, in both languages" do
    accounts_players(:moderator).update_columns(persona_name: "Hugo")
    win = bell_duel_line(duel_line(kind: :finished, outcome: :win, score: 6, other_score: 4))

    assert_equal [ "duel:#{TOKEN}", false, "See" ], [ win.key, win.lasting, win.action ]
    assert_equal "Duel against Hugo finished: victory, 6 to 4.", win.sentence
    I18n.with_locale(:fr) do
      assert_equal "Duel contre Hugo terminé\u202f: défaite, 3 à 7.", bell_duel_line(duel_line(kind: :finished, outcome: :loss, score: 3, other_score: 7)).sentence
      assert_equal "Duel contre Hugo terminé\u202f: égalité, 5 à 5.", bell_duel_line(duel_line(kind: :finished, outcome: :draw, score: 5, other_score: 5)).sentence
    end
  end
end
