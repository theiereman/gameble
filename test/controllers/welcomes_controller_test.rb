require "test_helper"
require_relative "../support/steam_sign_in"

class WelcomesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include SteamSignIn

  STEAM_ID = "76561197960287930".freeze

  def new_player = Accounts::Player.find_by!(steam_id: STEAM_ID)

  def close_jobs = enqueued_jobs.select { it["job_class"] == "Accounts::CloseWelcomeJob" }

  def sign_up(origin: "/fr")
    sign_in_new_player(STEAM_ID, origin:)
    follow_redirect!
  end

  test "a new player's first hub shows the Brotherhood's welcome in French instead of the sign-in toast, then never again" do
    sign_up

    assert_nil flash[:notice]
    assert_select "#toasts > .toast", 0
    assert_select "dialog#welcome-panel.modal[aria-labelledby=welcome-title]:not([open])" do
      assert_select "p#welcome-title", "Bienvenue sur gameble"
      assert_select "p.welcome-dialog__line", 4
      assert_select "p.welcome-dialog__line", "Autrefois bannis de la Terre, les jeux vidéo ont été sauvés grâce aux efforts de nos illustres fondateurs."
      assert_select "p.welcome-dialog__line", "Aujourd'hui, la Grande Confrérie des Gameblers a l'honneur de vous donner accès à cet héritage, " \
        "sous forme de cartes distribuées aléatoirement dans nos capsules, afin de garantir une parfaite équité entre nos membres."
      assert_select "p.welcome-dialog__line", "Il ne vous reste plus qu'à constituer votre collection."
      assert_select "p.welcome-dialog__line", "La Confrérie vous souhaite d'excellents tirages."
      assert_select "form[action='/fr/welcome'][method=post] input[name=_method][value=delete]"
      assert_select "form[action='/fr/welcome'] button.button--secondary[autofocus]", "Fermer"
      assert_select "button.modal__close[aria-label=Fermer]"
    end
    assert_select ".hub > header + #welcome-panel", 1, "after the heading in reading order"
    assert_select "#hub-title[tabindex='-1']"
    assert_select "#welcome-panel [style]", 0
    assert_no_match(/["\/=]#{new_player.id}["\/&]/, css_select("#welcome-panel").sole.to_html)
    assert_equal 1, close_jobs.size
    assert new_player.welcome_pending, "the hub GET wrote nothing"

    perform_enqueued_jobs
    assert_not new_player.welcome_pending

    get home_path(locale: :fr)
    assert_select "#welcome-panel", 0
    assert_select ".welcome-dialog", 0
  end

  test "the welcome reads in English" do
    sign_up(origin: "/en")

    assert_select "#welcome-panel" do
      assert_select "p#welcome-title", "Welcome to gameble"
      assert_select "p.welcome-dialog__line", "Once banished from Earth, video games were saved through the efforts of our illustrious founders."
      assert_select "p.welcome-dialog__line", "Today, the Great Brotherhood of Gameblers is honored to grant you access to this legacy through cards " \
        "randomly distributed in our capsules, ensuring complete fairness among our members."
      assert_select "p.welcome-dialog__line", "All that remains is for you to build your collection."
      assert_select "p.welcome-dialog__line", "The Brotherhood wishes you excellent pulls."
      assert_select "form[action='/en/welcome'] button", "Close"
    end
  end

  test "while a welcome is pending, pages turn link prefetching off, so the hub is never read ahead of a click" do
    sign_up

    get home_path(locale: :fr)
    assert_select "meta[name='turbo-prefetch'][content='false']"
    assert_select "[data-turbo-permanent]#welcome-panel"

    perform_enqueued_jobs
    get home_path(locale: :fr)
    assert_select "meta[name='turbo-prefetch']", count: 0
  end

  test "the close button closes the welcome for good: from Turbo the panel is removed, without JavaScript the hub comes back without it" do
    sign_up

    delete welcome_path(locale: :fr), as: :turbo_stream
    assert_response :success
    assert_select "turbo-stream[action=remove][target=welcome-panel]"
    assert_not new_player.welcome_pending

    new_player.update_columns(welcome_pending: true)
    delete welcome_path(locale: :fr)
    assert_redirected_to home_path(locale: :fr)
    assert_response :see_other
    assert_not new_player.welcome_pending
    follow_redirect!
    assert_select "#welcome-panel", 0
  end

  test "a player whose welcome is closed signs in to the toast and no panel" do
    sign_in(accounts_players(:player), origin: "/fr")

    assert_equal "Bienvenue sur gameble. Vos capsules vous attendent.", flash[:notice]
    follow_redirect!
    assert_select "#welcome-panel", 0
    assert_empty close_jobs
  end

  test "a visitor cannot close a welcome" do
    delete welcome_path(locale: :fr)

    assert_redirected_to home_path(locale: :fr)
    assert_equal I18n.t("authorization.sign_in_required", locale: :fr), flash[:alert]
  end
end
