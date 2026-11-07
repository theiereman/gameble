require "test_helper"
require_relative "../support/steam_sign_in"

# Where the header's bell sits: beside the player chip for a signed-in
# player, on top-level and drill-down pages alike; never for a visitor or
# in the back-office.
class BellSlotTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  BELL = ".top-bar__end > .bell[data-controller=bell] + .phone-menu + .player-chip".freeze

  def assert_bell(locale: :en)
    assert_select ".top-bar__end > .bell[data-controller=bell]", 1 do
      assert_select "button.bell__button[type=button][popovertarget=bell-panel]" do
        assert_select "svg.pixel-icon.bell__icon"
        assert_select ".visually-hidden[data-bell-target=label]"
        assert_select ".bell__count[data-bell-target=count][hidden]"
      end
      assert_select "#bell-panel.shell-popover[popover][aria-labelledby=bell-title] turbo-frame#bell-items[src='/#{locale}/bell'][target=_top][data-bell-target=frame]"
    end
    assert_select BELL
  end

  test "a player's top-level screen carries the bell, with its plural labels" do
    sign_in(accounts_players(:player))

    get home_path(locale: :en)

    assert_select "header.top-bar--top-level"
    assert_bell
    bell = css_select(".bell").sole
    assert_equal accounts_players(:player).token, bell["data-bell-owner-value"]
    assert_equal "turbo:morph@document->bell#show turbo:before-cache@document->bell#reloadWhenRestored", bell["data-action"]
    assert_select "turbo-frame#bell-items[refresh=morph][data-action='turbo:frame-render->bell#show turbo:frame-missing->bell#keep']"
    labels = JSON.parse(bell["data-bell-labels-value"])
    assert_equal({ "zero" => "What is new, all seen", "one" => "What is new, %{count} unseen", "other" => "What is new, %{count} unseen" }, labels)
  end

  test "the Me page, a top-level screen, carries it" do
    sign_in(accounts_players(:player))

    get me_path(locale: :en)

    assert_select "header.top-bar--top-level"
    assert_bell
  end

  test "a drill-down page carries it too, in the page's locale" do
    sign_in(accounts_players(:player))

    get feed_path(locale: :fr)

    assert_select "header.top-bar--top-level", false
    assert_bell(locale: :fr)
    assert_select "#bell-panel .shell-popover__title", "Nouveautés"
  end

  test "a visitor has no bell" do
    get library_cards_path(locale: :en)

    assert_select ".bell, #bell-panel", false
  end

  test "the back-office has no bell" do
    sign_in(accounts_players(:administrator))

    get back_office_path(locale: :en)

    assert_select ".player-chip"
    assert_select ".bell, #bell-panel", false
  end
end
