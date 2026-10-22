require "test_helper"
require_relative "../support/counting_rate_limit"
require_relative "../support/steam_sign_in"

class InvitationsControllerTest < ActionDispatch::IntegrationTest
  include CountingRateLimit
  include SteamSignIn

  setup do
    @alice = accounts_players(:player)
    @bob = accounts_players(:moderator)
    @bob.update!(persona_name: "Sam")
    @alice.update!(persona_name: "Lea")
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
    assert_select ".friends__message--sent", "Invitation envoyée à Sam."
    assert_select ".friends__invitation", /Envoyée à Sam/
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

  test "the sender cancels a sent invitation: the row is gone for both and the line says so" do
    sign_in @alice
    post invitations_path(locale: :fr), params: { code: "8F2D-K9XM" }
    follow_redirect!
    token = Game::Invitation.sole.token
    assert_select ".friends__invitation form[action=?] button[aria-label=?]", cancel_invitation_path(token:, locale: :fr),
      "Annuler l'invitation à Sam", text: "Annuler"

    post cancel_invitation_path(token:, locale: :fr)
    assert_redirected_to friends_path(locale: :fr)
    follow_redirect!

    assert_select ".friends__message--sent", "Invitation annulée."
    assert_select ".friends__invitation", 0
    delete session_path
    sign_in @bob
    get friends_path(locale: :fr)
    assert_select ".friends__invitation", 0
  end

  test "cancelling an invitation already accepted changes nothing and says it is no longer there" do
    invitation = Game::SendInvitation.new.call(player: @alice, code: "8F2D-K9XM").value!
    Game::AcceptInvitation.new.call(player: @bob, token: invitation.token).value!
    sign_in @alice

    post cancel_invitation_path(token: invitation.token, locale: :fr)
    follow_redirect!

    assert_select ".friends__message--error", "Cette invitation n'existe plus."
    assert_select ".friends__row .friends__name", "Sam"
    assert_equal "accepted", invitation.reload.status
  end

  test "the recipient cannot cancel the invitation they received" do
    invitation = Game::SendInvitation.new.call(player: @alice, code: "8F2D-K9XM").value!
    sign_in @bob

    post cancel_invitation_path(token: invitation.token, locale: :fr)
    follow_redirect!

    assert_select ".friends__message--error", "Cette invitation n'existe plus."
    assert_equal "pending", invitation.reload.status
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

  test "a visitor cannot send, answer or cancel" do
    post invitations_path(locale: :fr), params: { code: "8F2D-K9XM" }
    assert_redirected_to home_path(locale: :fr)
    post accept_invitation_path(token: "a" * 24, locale: :fr)
    assert_redirected_to home_path(locale: :fr)
    post cancel_invitation_path(token: "a" * 24, locale: :fr)
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
    assert_select "main form.button-form[action='/auth/steam'][method=post][data-turbo=false]" do
      assert_select "input[name=origin][value=?]", link
      assert_select "button.button--primary[type=submit]", /Se connecter/
    end
    assert_select "[aria-haspopup=dialog]", false

    sign_in @alice, origin: link
    follow_redirect!

    assert_equal link, path
    assert_select "[data-controller=auto-submit] form[action=?][method=post] button", link, text: "Envoyer une invitation"
    assert_equal 0, Game::Invitation.count
  end

  test "a signed-in player opening a link gets a form that sends itself, and the page writes nothing" do
    link = invite_link_path(token: @bob.token, locale: :fr)
    sign_in @alice

    get link

    assert_response :success
    assert_select "[data-controller=auto-submit] form[action=?][method=post] button", link, text: "Envoyer une invitation"
    assert_equal 0, Game::Invitation.count

    post link
    follow_redirect!
    assert_select ".friends__message--sent", "Invitation envoyée à Sam."
    assert_select ".friends__invitation", /Envoyée à Sam/
  end

  test "reopening a link after sending says it is already sent and sends nothing" do
    link = invite_link_path(token: @bob.token, locale: :fr)
    sign_in @alice
    post link

    get link

    assert_select ".friends__message", "Invitation déjà envoyée à Sam."
    assert_select "a[href=?]", friends_path(locale: :fr), text: "Vers vos amis"
    assert_select "[data-controller=auto-submit]", 0
    assert_select "form[action=?]", link, 0
    assert_equal 1, Game::Invitation.count
  end

  test "an ignored invitation still reads as already sent on the link" do
    invitation = Game::SendInvitation.new.call(player: @alice, recipient_token: @bob.token).value!
    Game::IgnoreInvitation.new.call(player: @bob, token: invitation.token).value!
    sign_in @alice

    get invite_link_path(token: @bob.token, locale: :fr)

    assert_select ".friends__message", "Invitation déjà envoyée à Sam."
    assert_select "[data-controller=auto-submit]", 0
  end

  test "an ignored invitation gives way to the owner's pending one: the link offers the form, which accepts it" do
    ignored = Game::SendInvitation.new.call(player: @alice, recipient_token: @bob.token).value!
    Game::IgnoreInvitation.new.call(player: @bob, token: ignored.token).value!
    Game::SendInvitation.new.call(player: @bob, recipient_token: @alice.token).value!
    link = invite_link_path(token: @bob.token, locale: :fr)
    sign_in @alice

    get link

    assert_select "[data-controller=auto-submit] form[action=?]", link
    assert_select ".friends__message", 0

    post link
    follow_redirect!
    assert_select ".friends__row .friends__name", "Sam"
  end

  test "a friend opening the link is told they are already friends, with no form" do
    link = invite_link_path(token: @bob.token, locale: :en)
    invitation = Game::SendInvitation.new.call(player: @alice, recipient_token: @bob.token).value!
    Game::AcceptInvitation.new.call(player: @bob, token: invitation.token).value!
    sign_in @alice

    get link

    assert_select ".friends__message", "You and Sam are already friends."
    assert_select "a[href=?]", friends_path(locale: :en), text: "To your friends"
    assert_select "[data-controller=auto-submit]", 0
    assert_select "form[action=?]", link, 0
  end

  test "a player the owner invited gets the sending form, which accepts the invitation" do
    Game::SendInvitation.new.call(player: @bob, recipient_token: @alice.token).value!
    link = invite_link_path(token: @bob.token, locale: :fr)
    sign_in @alice

    get link
    assert_select "[data-controller=auto-submit] form[action=?]", link

    post link
    follow_redirect!
    assert_select ".toast", /Nouvel ami/i
    assert_select ".friends__row .friends__name", "Sam"
  end

  test "sending from a link invites the owner" do
    sign_in @alice
    post invite_link_path(token: @bob.token, locale: :fr)
    assert_redirected_to friends_path(locale: :fr)
    follow_redirect!

    assert_select ".friends__message--sent", "Invitation envoyée à Sam."
    assert_select ".friends__invitation", /Envoyée à Sam/
    assert_equal [ @alice.id, @bob.id ], Game::Invitation.pending.pick(:sender_id, :recipient_id)
  end

  test "an invitation to a player with no usable name shows their code" do
    @bob.update!(persona_name: "\u200B")
    sign_in @alice
    post invitations_path(locale: :fr), params: { code: "8F2D-K9XM" }
    follow_redirect!

    assert_select ".friends__message--sent", "Invitation envoyée à 8F2D-K9XM."
    assert_select ".friends__invitation", /Envoyée à 8F2D-K9XM/
  end

  test "a link invitation to a player with no usable name shows their code" do
    @bob.update!(persona_name: "\u200B")
    sign_in @alice
    post invite_link_path(token: @bob.token, locale: :fr)
    follow_redirect!

    assert_select ".friends__message--sent", "Invitation envoyée à 8F2D-K9XM."
    assert_select ".friends__invitation", /Envoyée à 8F2D-K9XM/
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
