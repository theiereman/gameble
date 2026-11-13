require "test_helper"
require_relative "../support/steam_sign_in"

class ProfileAvatarsControllerTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    Game::AchievementUnlock.record(@player.id, "first_booster", Time.current)
  end

  def stored = Game::PlayerState.where(player_id: @player.id).pick(:active_avatar)

  test "a visitor is sent to sign in" do
    patch personalization_avatar_path(locale: :en), params: { avatar: "novice" }

    assert_response :redirect
    assert_nil stored
  end

  test "the Me page puts a pencil on the portrait that opens the avatar sheet, locked avatars naming their achievement" do
    sign_in(@player)

    get me_path(locale: :fr)

    assert_select ".profile-band__portrait .profile-band__avatar"
    assert_select ".profile-band__portrait a.profile-band__avatar-edit[href='#me-avatar-sheet'][aria-label=?]", "Changer d'avatar"
    assert_select "#me-avatar-sheet .me-avatar", 20
    assert_select "#me-avatar-sheet button[type=button][aria-current=true]", /Classique/
    assert_select "#me-avatar-sheet form input[name=avatar][value=novice]"
    %w[mechanic pilot cartographer botanist streamer elder astronaut punk chef robot cat alien slime owl].each { assert_select "#me-avatar-sheet form input[name=avatar][value=#{it}]" }
    assert_select "#me-avatar-sheet .me-avatar__name", "Mécanicienne"
    assert_select "#me-avatar-sheet .me-avatar--locked", 4
    assert_select "#me-avatar-sheet .me-avatar--locked .me-avatar__unlock", /Oiseau de nuit/
    assert_select "#me-avatar-sheet input[name=avatar][value=guardian]", false
    assert_select "#me-avatar-sheet .me-avatar__name", text: "Grand Maître", count: 0
    assert_select "[style]", false
  end

  test "choosing an unlocked avatar stores it and shows it in the band and the top bar" do
    sign_in(@player)

    patch personalization_avatar_path(locale: :en), params: { avatar: "novice" }

    assert_redirected_to me_path(locale: :en)
    assert_equal "novice", stored
    follow_redirect!
    assert_select ".toast", /Avatar changed/
    assert_select ".profile-band__avatar path", minimum: 1
    assert_select "a.profile-band__avatar-edit[autofocus]"
    assert_select "#me-avatar-sheet button[type=button][aria-current=true]", /Novice/
    assert_equal css_select(".player-chip__avatar").first.to_html.sub(/class="[^"]*"/, ""),
      css_select(".profile-band__avatar").first.to_html.sub(/class="[^"]*"/, "")
  end

  test "a locked avatar is refused and changes nothing" do
    sign_in(@player)

    assert_no_difference -> { Rails.configuration.event_store.read.count } do
      patch personalization_avatar_path(locale: :en, format: :json), params: { avatar: "oracle" }
    end

    assert_response :unprocessable_content
    assert_equal "avatar_locked", response.parsed_body.dig("error", "code")
    assert_nil stored
  end

  test "another player's profile shows their avatar without the pencil" do
    Game::ChooseAvatar.new.call(player: @player, avatar: "novice").value!
    sign_in(accounts_players(:moderator))

    get brother_path(locale: :en, token: @player.token)

    assert_select ".profile-band__avatar"
    assert_select ".profile-band__avatar-edit", false
    assert_select "#me-avatar-sheet", false
  end
end
