require "test_helper"
require_relative "../support/steam_sign_in"

class CardBacksControllerTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    Game::CardBackUnlock.record(@player.id, "set-theme-rpg", Time.current)
  end

  def achievement(key, locale) = "#{I18n.t("achievements.names.#{key}", locale:)} · #{I18n.t("achievements.conditions.#{key}", locale:)}"

  def stored = Game::PlayerState.where(player_id: @player.id).pick(:active_card_back)

  test "a visitor is sent to sign in" do
    patch personalization_back_path(locale: :en), params: { back: "set-theme-rpg" }

    assert_response :redirect
    assert_nil stored
  end

  test "the page groups the backs, names the active one in the strip and offers the unlocked ones as forms" do
    sign_in(@player)

    get me_path(locale: :fr)

    assert_select "#me-back-sheet-title", "Dos de carte"
    assert_select ".back-picker__strip[aria-hidden=true][data-showing=active]" do
      assert_select ".back-picker__chip--active", "Actif"
      assert_select ".back-picker__name", "Standard"
      assert_select ".back-picker__sentence", "Offert à tous les joueurs"
      assert_select ".back-picker__tail", "à l'inscription"
    end
    assert_equal [ "De base et événements", "Succès", "Mission de la Confrérie", "Sets · Thèmes", "Sets · Palmarès" ], css_select(".back-picker__group-name").map(&:text)
    assert_select "#me-back-sheet .me-sheet__count .visually-hidden", "2 sur #{Game::CardBacks::KEYS.size} débloqués"
    assert_select ".me-back-opener .me-opener__kicker", "Dos de carte · vous seul"
    assert_select ".back-picker__tile--active", 1
    assert_select ".back-picker__tile--active button[aria-label=?]", "Standard, actif. Offert à tous les joueurs, à l'inscription."
    assert_select ".back-picker__tile--locked", Game::CardBacks::KEYS.size - 2
    assert_select ".back-picker__tile--locked button[type=button]", Game::CardBacks::KEYS.size - 2
    assert_select ".back-picker__tile form[action$='/personalization/back'] input[name=back][value='set-theme-rpg']"
    assert_select ".back-picker__tile[data-key='set-theme-rpg'] button[data-active-label^='RPG, actif.'][data-unlocked-label$='Équiper.']"
    assert_select ".back-picker__tile[data-key='etoile-dor'] button[aria-label=?]",
      "Étoile d'or, verrouillé. Débloquez le succès #{achievement(:first_legendary, :fr)}."
    assert_select ".back-picker__plate[aria-hidden=true]", 2
    assert_select "p.visually-hidden[role=status][data-back-picker-target=status]", ""
    assert_select "template[data-back-picker-target=failure]"
    assert_select "[style]", false
  end

  test "each back says how it was earned, in English and in French" do
    Game::CardBackUnlock.record(@player.id, "centurion", Time.zone.local(2026, 10, 24, 10))
    Game::CardBackUnlock.record(@player.id, "confrere", Time.zone.local(2026, 10, 18, 10))
    Game::GoalReward.create!(player_id: @player.id, week_start: Date.new(2026, 10, 12))
    sign_in(@player)

    get me_path(locale: :en)

    assert_select "[data-key=centurion] button[aria-label=?]", "Centurion, unlocked. Earned with the achievement #{achievement(:boosters_100, :en)}, on October 24, 2026. Equip."
    assert_select "[data-key=confrere] button[aria-label=?]", "Confrère, unlocked. Earned by completing the mission of the week of October 12, on October 18, 2026. Equip."
    assert_select "[data-key=etoile-dor] button[aria-label=?]", "Golden star, locked. Unlock the achievement #{achievement(:first_legendary, :en)}."

    get me_path(locale: :fr)

    assert_select "[data-key=centurion] template.back-picker__detail", text: /Gagné avec le succès #{Regexp.escape(achievement(:boosters_100, :fr))}\s+le 24 octobre 2026/
    assert_select "[data-key=confrere] button[aria-label=?]", "Confrère, débloqué. Gagné en accomplissant la mission de la semaine du 12 octobre, le 18 octobre 2026. Équiper."
  end

  test "choosing an unlocked back without script stores it and sends its sheet open with the focus back on it, with no toast" do
    sign_in(@player)

    patch personalization_back_path(locale: :en), params: { back: "set-theme-rpg" }

    assert_redirected_to me_path(locale: :en)
    assert_equal "set-theme-rpg", stored
    follow_redirect!
    assert_select ".toast", text: /equipped/i, count: 0
    assert_select ".back-picker__strip .back-picker__name", "RPG"
    assert_select "dialog#me-back-sheet[open] .back-picker__tile--active[data-key='set-theme-rpg'] button[autofocus]"
    assert_select ".me-back-opener [data-me-target=preview] .me-opener__value", "RPG"
    assert_select "dialog[open]", 1
    assert_select "[autofocus]", 1
  end

  test "choosing in JSON answers with the back, its season and the announcement" do
    sign_in(@player)

    patch personalization_back_path(locale: :fr), params: { back: "set-theme-rpg" }, as: :json

    assert_response :success
    assert_equal({ "back" => "set-theme-rpg", "season" => nil, "announcement" => "Dos équipé. « RPG » apparaîtra sur vos cartes face cachée." }, response.parsed_body)
    assert_equal "set-theme-rpg", stored
    assert_nil flash[:chosen_back]
  end

  test "a forged locked or unknown back changes nothing" do
    sign_in(@player)

    assert_no_difference -> { Rails.configuration.event_store.read.count } do
      patch personalization_back_path(locale: :en, format: :json), params: { back: "set-theme-horror" }
      assert_response :unprocessable_content
      assert_equal "back_locked", response.parsed_body.dig("error", "code")

      patch personalization_back_path(locale: :en, format: :json), params: { back: "not-a-back" }
      assert_response :unprocessable_content
      assert_equal "unknown_back", response.parsed_body.dig("error", "code")
    end

    assert_nil stored
  end

  test "a locked back submitted from the page answers with the alert toast" do
    sign_in(@player)

    patch personalization_back_path(locale: :en), params: { back: "set-theme-horror" }, as: :turbo_stream

    assert_response :unprocessable_content
    assert_includes response.body, "still locked"
    assert_nil stored
  end
end
