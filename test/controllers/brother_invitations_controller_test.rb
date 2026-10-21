require "test_helper"
require_relative "../support/steam_sign_in"

class BrotherInvitationsControllerTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  setup do
    @owner = accounts_players(:player)
    @owner.update_columns(persona_name: "Gabe the Brave")
    @viewer = accounts_players(:moderator)
  end

  def befriend(first, second)
    Game::Friendship.create!(low_player_id: [ first.id, second.id ].min, high_player_id: [ first.id, second.id ].max)
  end

  def action_buttons = css_select(".profile-band__identity .button")

  test "a signed-in viewer without relation sees ADD FRIEND posting the invitation" do
    sign_in(@viewer)
    get brother_path(locale: :en, token: @owner.token)

    assert_select "form[action=?] button[aria-label=?]", brother_invitation_path(locale: :en, token: @owner.token),
      "Add Gabe the Brave as a friend", text: "ADD FRIEND"
  end

  test "adding sends the invitation and the profile shows PENDING" do
    sign_in(@viewer)

    assert_difference -> { Game::Invitation.count }, 1 do
      post brother_invitation_path(locale: :en, token: @owner.token)
    end
    assert_redirected_to brother_path(locale: :en, token: @owner.token)
    assert Game::InvitationAwaiting.call(@viewer, @owner)
    follow_redirect!

    assert_select ".profile-band__identity button[disabled]", "PENDING"
    assert_select "form[action=?]", brother_invitation_path(locale: :en, token: @owner.token), 0
  end

  test "a second post writes nothing and alerts" do
    sign_in(@viewer)
    post brother_invitation_path(locale: :en, token: @owner.token)

    assert_no_difference -> { Game::Invitation.count } do
      post brother_invitation_path(locale: :en, token: @owner.token)
    end
    assert_equal "Invitation already sent.", flash[:alert]
  end

  test "a received invitation shows ACCEPT, which makes them friends and shows TRADE" do
    Game::SendInvitation.new.call(player: @owner, recipient_token: @viewer.token)
    sign_in(@viewer)
    get brother_path(locale: :en, token: @owner.token)
    assert_select ".profile-band__identity button", "ACCEPT"

    post brother_invitation_path(locale: :en, token: @owner.token)
    assert Game::FriendshipBetween.call(@viewer, @owner)
    follow_redirect!

    assert_select ".profile-band__identity a.button[href=?]", new_trade_path(locale: :en, friend: @owner.token), "TRADE"
  end

  test "friends with an open trade link to it" do
    befriend(@owner, @viewer)
    one = catalog_card_seasons(:portal_one).id
    three = catalog_card_seasons(:rare_card_one).id
    Game::Holding.create!(player_id: @owner.id, card_season_id: one, quantity: 2, reserved: 0)
    Game::Holding.create!(player_id: @viewer.id, card_season_id: three, quantity: 2, reserved: 0)
    trade = Game::ProposeTrade.new.call(player: @viewer, recipient: @owner, offer: { three => 1 }, request: { one => 1 }).value!
    sign_in(@viewer)
    get brother_path(locale: :en, token: @owner.token)

    assert_select ".profile-band__identity a.button[href=?]", trade_path(locale: :en, token: trade.token), "TRADE"
  end

  test "friends without a trade link to a new draft" do
    befriend(@owner, @viewer)
    sign_in(@viewer)
    get brother_path(locale: :en, token: @owner.token)

    assert_select ".profile-band__identity a.button[href=?]", new_trade_path(locale: :en, friend: @owner.token), "TRADE"
  end

  test "staff get no action on a private profile and cannot invite its owner" do
    @owner.update!(visibility: "private")
    sign_in(@viewer)
    get brother_path(locale: :en, token: @owner.token)

    assert_response :success
    assert_select ".profile-band__identity form", 0
    assert_select ".profile-band__identity .button", 1

    assert_no_difference -> { Game::Invitation.count } do
      post brother_invitation_path(locale: :en, token: @owner.token)
    end
    assert_response :not_found
  end

  test "a banned owner's profile gets no invitation" do
    @owner.update_columns(banned_at: Time.current)
    sign_in(@viewer)

    assert_no_difference -> { Game::Invitation.count } do
      post brother_invitation_path(locale: :en, token: @owner.token)
    end
    assert_response :not_found
  end

  test "friends with a private viewer see the trades-closed line" do
    Game::Friendship.create!(low_player_id: [ @owner.id, @viewer.id ].min, high_player_id: [ @owner.id, @viewer.id ].max)
    @viewer.update!(visibility: "private")
    sign_in(@viewer)
    get brother_path(locale: :en, token: @owner.token)

    assert_select ".profile-band__identity .trades-closed"
    assert_select ".profile-band__identity a.button", false
  end

  test "the own profile has no action and the post is refused" do
    sign_in(@owner)
    get brother_path(locale: :en, token: @owner.token)
    assert_select ".profile-band__identity .button", false

    assert_no_difference -> { Game::Invitation.count } do
      post brother_invitation_path(locale: :en, token: @owner.token)
    end
    assert_equal "That is your own link.", flash[:alert]
  end

  test "a visitor sees TRADE disabled and the post is refused" do
    get brother_path(locale: :en, token: @owner.token)
    assert_select ".profile-band__identity button[disabled]", "TRADE"

    assert_no_difference -> { Game::Invitation.count } do
      post brother_invitation_path(locale: :en, token: @owner.token)
    end
    assert_response :redirect
  end

  test "a private profile takes no invitation" do
    @owner.update!(visibility: "private")
    sign_in(Accounts::Player.create!(steam_id: "76561197960390102"))

    assert_no_difference -> { Game::Invitation.count } do
      post brother_invitation_path(locale: :en, token: @owner.token)
    end
    assert_response :not_found
  end

  test "a GET of a profile writes nothing" do
    sign_in(@viewer)
    assert_no_difference -> { Game::Invitation.count } do
      get brother_path(locale: :en, token: @owner.token)
    end
  end
end
