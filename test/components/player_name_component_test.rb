require "test_helper"

class PlayerNameComponentTest < ViewComponent::TestCase
  setup do
    @owner = Accounts::Player.create!(steam_id: "76561198000001111", persona_name: "Alice")
    @viewer = accounts_players(:player)
  end

  def name_for(player, viewer = @viewer) = render_inline(PlayerNameComponent.new(player:, viewer:))

  test "a visible player is a name linked to the profile by token" do
    name_for(@owner)

    assert_selector "a.player-name.player-name--linked[href=?]", "/en/brothers/#{@owner.token}", text: "Alice"
  end

  test "a private player shows as a bare name with no link" do
    @owner.update_columns(visibility: Accounts::Player.visibilities.fetch("private"))
    name_for(@owner)

    assert_selector "span.player-name", text: "Alice"
    assert_no_selector "a"
    assert_no_selector ".player-name--linked"
  end

  test "a friends-only player is bare for a stranger" do
    @owner.update_columns(visibility: Accounts::Player.visibilities.fetch("friends_only"))
    name_for(@owner)

    assert_selector "span.player-name", text: "Alice"
    assert_no_selector "a"
  end

  test "a banned or deleted player shows the anonymous key, never the name" do
    @owner.update_columns(banned_at: Time.current)
    name_for(@owner)
    assert_selector "span.player-name.player-name--anonymous", text: "An anonymous player"
    assert_no_text "Alice"

    @owner.update_columns(banned_at: nil, deleted_at: Time.current)
    name_for(@owner)
    assert_selector "span.player-name--anonymous"
    assert_no_selector "a"
  end

  test "a visitor reads a public name as a link and a private one bare" do
    name_for(@owner, nil)
    assert_selector "a.player-name--linked", text: "Alice"

    @owner.update_columns(visibility: Accounts::Player.visibilities.fetch("private"))
    name_for(@owner, nil)
    assert_no_selector "a"
  end

  test "a player with no usable name shows the fallback name" do
    @owner.update_columns(persona_name: "​")
    name_for(@owner)

    assert_selector "a.player-name", text: I18n.t("shell.player.fallback_name")
  end

  test "the anonymous key reads in French" do
    @owner.update_columns(banned_at: Time.current)
    I18n.with_locale(:fr) { name_for(@owner) }

    assert_selector ".player-name--anonymous", text: "Un joueur anonyme"
  end
end
