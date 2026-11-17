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

  test "a wanted card on sale names the card and its starting price, and leads to the Annonce" do
    line = bell_market_line(market_notice(kind: :wanted, other: nil, amount: 1_300))

    assert_equal market_listing_path(token: "tok"), line.path
    assert_includes line.sentence, "Portal, missing from your goals, is on sale from"
    I18n.with_locale(:fr) { assert_includes bell_market_line(market_notice(kind: :wanted, other: nil)).sentence, "Portal, qui manque à vos objectifs, est en vente" }
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

  test "a market line comes after the reaction lines and before the daily capsule" do
    items = Game::BellItems::Result.new(trades: [], updates: [], invitations: [], reactions: [], market: [ market_notice ], daily: nil, duels: [],
      goal: Game::BellItems::GoalLine.new(week_start: Date.new(2026, 11, 9), reward_ready: false, target: 10, reached: false))

    assert_equal [ "market", "mission" ], bell_lines(items).map { it.key.split(":").first }
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
