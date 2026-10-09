require "test_helper"
require_relative "../support/game_packs"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  include GamePacks

  setup do
    OmniAuth.config.test_mode = true
    @player = accounts_players(:player)
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  def sign_in(steam_id = @player.steam_id)
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{steam_id}")
    post "/auth/steam", params: { origin: "/en" }
    follow_redirect!
    assert session[:player_id]
  end

  test "the settings screen has the COMPTE row and the delete dialog, the button disabled by script only" do
    sign_in

    get settings_path(locale: :fr)

    assert_select ".settings-row__label", "Compte"
    assert_select "button.button--danger[aria-haspopup=dialog][data-dialog-opener-dialog-value=delete-dialog]", "Supprimer mon compte"
    assert_select "dialog#delete-dialog[aria-labelledby=delete-dialog-title]" do
      assert_select "#delete-dialog-title", "Supprimer mon compte"
      assert_select "form[action='/fr/account'][data-turbo=false][data-controller=confirm-word][data-confirm-word-word-value=SUPPRIMER]"
      assert_select "input[name=_method][value=delete]", visible: :all
      assert_select "label[for=delete-confirmation]", "Tapez SUPPRIMER pour confirmer"
      assert_select "input#delete-confirmation[name=confirmation][autocomplete=off][aria-describedby=delete-dialog-note]"
      assert_select "button[type=submit].button--danger:not([disabled])", "Supprimer définitivement"
      assert_select "button[type=button][data-action='dialog#close']", "Annuler"
    end

    get settings_path(locale: :en)
    assert_select "form[action='/en/account'][data-confirm-word-word-value=DELETE]"
    assert_select "label[for=delete-confirmation]", "Type DELETE to confirm"
  end

  [ "SUPPRIMER", "supprimer", "  Supprimer \n" ].each do |word|
    test "typing #{word.inspect} deletes the account, signs the player out and lands on the hub with a toast" do
      create_pack(@player)
      token = @player.token
      sign_in

      delete account_path(locale: :fr), params: { confirmation: word }

      assert_redirected_to home_path(locale: :fr)
      assert_response :see_other
      assert_nil session[:player_id]
      assert_predicate @player.reload, :deleted?
      assert_equal 0, Game::Pack.where(player_id: @player.id).count
      follow_redirect!
      assert_select ".hub-invitation"
      assert_select ".toast", /Votre compte a été supprimé/

      get brother_path(token:, locale: :fr)
      assert_response :not_found
    end
  end

  test "the English word is DELETE, and the player's motion preference stays as a cookie" do
    @player.update!(reduced_motion: true)
    sign_in

    delete account_path(locale: :en), params: { confirmation: "delete" }

    assert_redirected_to home_path(locale: :en)
    assert_predicate @player.reload, :deleted?
    assert_equal "reduced", cookies[:motion]
    assert_equal "Your account has been deleted. Thank you for playing.", flash[:notice]
  end

  [ nil, "", "SUPPRIME", "SUPPRIMER DÉFINITIVEMENT", "DELETE", [ "SUPPRIMER" ] ].each do |word|
    test "#{word.inspect} is not the word: nothing is deleted, back to the settings with the reason" do
      create_pack(@player)
      sign_in

      delete account_path(locale: :fr), params: { confirmation: word }

      assert_redirected_to settings_path(locale: :fr)
      assert_equal "Tapez SUPPRIMER pour confirmer la suppression. Rien n'a été effacé.", flash[:alert]
      assert_not @player.reload.deleted?
      assert_equal 1, Game::Pack.where(player_id: @player.id).count
      assert session[:player_id]
    end
  end

  test "a visitor is sent home and asked to sign in; nothing is deleted" do
    delete account_path(locale: :en), params: { confirmation: "DELETE" }

    assert_redirected_to home_path(locale: :en)
    assert_equal I18n.t("authorization.sign_in_required", locale: :en), flash[:alert]
    assert_not @player.reload.deleted?
  end

  test "another browser still signed in as the deleted player becomes a visitor" do
    sign_in
    other_browser = open_session
    other_browser.post "/auth/steam", params: { origin: "/en" }
    other_browser.follow_redirect!
    assert other_browser.session[:player_id]

    delete account_path(locale: :en), params: { confirmation: "DELETE" }

    other_browser.get settings_path(locale: :en)
    other_browser.assert_redirected_to home_path(locale: :en)
    assert_nil other_browser.session[:player_id]
    other_browser.delete account_path(locale: :en), params: { confirmation: "DELETE" }
    other_browser.assert_redirected_to home_path(locale: :en)
  end

  test "the Steam id signs in again as a new player" do
    steam_id = @player.steam_id
    sign_in
    delete account_path(locale: :en), params: { confirmation: "DELETE" }

    sign_in(steam_id)

    assert_not_equal @player.id, session[:player_id]
    assert_equal steam_id, Accounts::Player.find(session[:player_id]).steam_id
  end
end
