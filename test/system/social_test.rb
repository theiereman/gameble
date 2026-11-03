require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/holdings"

# The Social home on a phone: the trades first, then the friends, the goal
# and the feed, with Add a friend and New trade held above the tab bar.
class SocialTest < ApplicationSystemTestCase
  include Holdings
  include SteamSignIn

  PHONE = [ 390, 844 ].freeze

  setup do
    @hugo = accounts_players(:player).tap { it.update!(persona_name: "Hugo") }
    @lea = accounts_players(:moderator).tap { it.update!(persona_name: "Lea") }
    @max = accounts_players(:administrator).tap { it.update!(persona_name: "Max") }
    [ @lea, @max ].each do |friend|
      low, high = [ @hugo.id, friend.id ].minmax
      Game::Friendship.create!(low_player_id: low, high_player_id: high)
    end
    hold(@hugo, catalog_card_seasons(:portal_one).id, 2)
    hold(@lea, catalog_card_seasons(:rare_card_one).id, 1)
    Game::ProposeTrade.new.call(player: @lea, recipient: @hugo, offer: { catalog_card_seasons(:rare_card_one).id => 1 },
      request: { catalog_card_seasons(:portal_one).id => 1 }).value!
  end

  test "on a phone, Social opens on the trades, its two actions above the tab bar, never covering the last section" do
    resize_to(*PHONE)
    mock_steam_sign_in(@hugo.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in

    find(".tab-bar a.tab-bar__tab[href='/en/social']").click

    assert_selector ".social-trade", text: /LEA/i
    assert_equal "Trades", page.evaluate_script("document.querySelector('.social h2').textContent.trim()")
    assert_selector ".social__actions a", text: /\AAdd a friend\z/i
    assert_selector ".social__actions a", text: /\ANew trade\z/i

    page.execute_script("window.scrollTo(0, document.documentElement.scrollHeight)")

    eventually("scrolled to the end, the last section should end above the actions") do
      layout = social_layout
      layout["lastBottom"] <= layout["actionsTop"] + 1 && layout["actionsBottom"] <= layout["tabBarTop"] + 1
    end
    assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth"), "Social should not scroll sideways"
  end

  private
    def social_layout
      page.evaluate_script(<<~JS)
        (() => {
          const actions = document.querySelector(".social__actions").getBoundingClientRect();
          const sections = [...document.querySelectorAll(".social > section")];
          return {
            actionsTop: actions.top,
            actionsBottom: actions.bottom,
            tabBarTop: document.querySelector(".tab-bar").getBoundingClientRect().top,
            lastBottom: sections[sections.length - 1].getBoundingClientRect().bottom
          };
        })()
      JS
    end
end
