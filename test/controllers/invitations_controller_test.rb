require "test_helper"
require_relative "../support/counting_rate_limit"

class InvitationsControllerTest < ActionDispatch::IntegrationTest
  include CountingRateLimit

  setup do
    OmniAuth.config.test_mode = true
    @alice = accounts_players(:player)
    @bob = accounts_players(:moderator)
    @bob.update!(persona_name: "Sam")
    @alice.update!(persona_name: "Lea")
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  def sign_in(player, origin: "/en")
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{player.steam_id}")
    post "/auth/steam", params: { origin: }
    follow_redirect!
  end

  test "the Friends screen shows the link, the field and no invitation" do
    sign_in @alice

    get friends_path(locale: :fr)

    assert_select "input#invite-link" do |input|
      assert input.first["value"].end_with?("/fr/invite/#{@alice.token}")
    end
    assert_select "form[action=?] input[name=code]", invitations_path(locale: :fr)
    assert_select ".friends__empty", /Aucune invitation en cours/
  end

  test "a code sends an invitation the friend sees, accepts, and both are friends" do
    sign_in @alice
    post invitations_path(locale: :fr), params: { code: "8f2d-k9xm" }
    assert_redirected_to friends_path(locale: :fr)
    follow_redirect!
    assert_select ".friends__message--sent", "Invitation envoyée à 8F2D-K9XM."
    assert_select ".friends__invitation", /Envoyée à 8F2D-K9XM/
    assert_select ".friends__chip", "En attente"

    delete session_path
    sign_in @bob
    get friends_path(locale: :fr)
    assert_select ".friends__invitation", /Lea vous invite/
    assert_select ".friends__invitation button", text: "Accepter"
    assert_select ".friends__invitation button", text: "Ignorer"
    token = Game::Invitation.last.token

    post accept_invitation_path(token:, locale: :fr)
    follow_redirect!
    assert_select ".toast", /Nouvel ami/i
    assert_select ".friends__row .friends__name", "Lea"
    assert_select ".friends__invitation", 0
  end

  test "an ignored invitation creates nothing" do
    invitation = Game::SendInvitation.new.call(player: @alice, code: "8F2D-K9XM").value!
    sign_in @bob

    post ignore_invitation_path(token: invitation.token, locale: :fr)
    follow_redirect!

    assert_select ".friends__invitation", 0
    assert_select ".friends__row", 0
    assert_equal 0, Game::Friendship.count
  end

  test "the copy deck's refusals answer on the line under the field" do
    sign_in @alice
    {
      "abc" => "Format attendu : ABCD-1234.",
      "7K2Q-F3NX" => "C'est votre propre code.",
      "2222-3333" => "Aucun joueur n'a ce code."
    }.each do |code, line|
      post invitations_path(locale: :fr), params: { code: }
      follow_redirect!
      assert_select ".friends__message--error", line
    end
    post invitations_path(locale: :fr), params: { code: "8F2D-K9XM" }
    post invitations_path(locale: :fr), params: { code: "8F2D-K9XM" }
    follow_redirect!
    assert_select ".friends__message--error", "Invitation déjà envoyée."
    assert_equal 1, Game::Invitation.count
  end

  test "in English the refusals are English" do
    sign_in @alice
    post invitations_path(locale: :en), params: { code: "x" }
    follow_redirect!

    assert_select ".friends__message--error", "Expected format: ABCD-1234."
  end

  test "a visitor cannot send or answer" do
    post invitations_path(locale: :fr), params: { code: "8F2D-K9XM" }
    assert_redirected_to home_path(locale: :fr)
    post accept_invitation_path(token: "a" * 24, locale: :fr)
    assert_redirected_to home_path(locale: :fr)
    assert_equal 0, Game::Invitation.count
  end

  test "answering someone else's invitation changes nothing" do
    invitation = Game::SendInvitation.new.call(player: @alice, code: "8F2D-K9XM").value!
    sign_in accounts_players(:administrator)

    post accept_invitation_path(token: invitation.token, locale: :fr)

    assert_equal "pending", invitation.reload.status
    assert_equal 0, Game::Friendship.count
  end

  test "a visitor opening a link signs in and lands back on it" do
    link = invite_link_path(token: @bob.token, locale: :fr)
    get link
    assert_response :success
    assert_select ".invite-link__line", /Sam vous invite/
    assert_select "button[aria-haspopup=dialog]", /Se connecter/
    assert_select "dialog#sign-in-panel input[name=origin][value=?]", link

    sign_in @alice, origin: link
    follow_redirect!

    assert_equal link, path
    assert_select "form[action=?] button", link, text: "Envoyer une invitation"
  end

  test "sending from a link invites the owner" do
    sign_in @alice
    post invite_link_path(token: @bob.token, locale: :fr)
    assert_redirected_to friends_path(locale: :fr)
    follow_redirect!

    assert_select ".friends__message--sent", "Invitation envoyée à Sam."
    assert_equal [ @alice.id, @bob.id ], Game::Invitation.pending.pick(:sender_id, :recipient_id)
  end

  test "a player's own link, a repeat and an unknown link" do
    sign_in @alice
    get invite_link_path(token: @alice.token, locale: :fr)
    assert_select ".friends__message--error", "C'est votre propre lien."

    post invite_link_path(token: @bob.token, locale: :fr)
    post invite_link_path(token: @bob.token, locale: :fr)
    follow_redirect!
    assert_select ".friends__message--error", "Invitation déjà envoyée."

    get invite_link_path(token: "A" * 24, locale: :fr)
    assert_response :not_found
    get invite_link_path(token: accounts_players(:banned).token, locale: :fr)
    assert_response :not_found
  end

  test "mutations are limited to 20 a minute" do
    sign_in @alice

    with_counting_rate_limit(InvitationsController) do
      21.times { post invitations_path(locale: :fr), params: { code: "abc" } }
    end

    assert_redirected_to friends_path(locale: :fr)
    assert_equal I18n.t("invitations.throttled", locale: :fr), flash[:alert]
  end
end
