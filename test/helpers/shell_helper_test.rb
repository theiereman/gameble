require "test_helper"
require_relative "../support/game_packs"

# The shell's helpers: pixel icons inlined, the back-office
# switch, and the top bar's figures read once per request.
class ShellHelperTest < ActionView::TestCase
  include GamePacks
  include ExchangesHelper
  include ApplicationHelper

  attr_accessor :current_player

  def controller_path
    @controller_path || super
  end

  def action_name
    @action_name || super
  end

  test "an icon is its exported SVG, inlined, hidden and never focusable" do
    html = pixel_icon("arrow-left")
    svg = Nokogiri::HTML5.fragment(html).at("svg")

    assert_predicate html, :html_safe?
    assert_equal "pixel-icon", svg["class"]
    assert_equal "true", svg["aria-hidden"]
    assert_equal "false", svg["focusable"]
    assert_equal "0 0 4 7", svg["viewbox"] || svg["viewBox"]
    assert_equal [ "8", "14" ], [ svg["width"], svg["height"] ]
    assert_equal "crispEdges", svg["shape-rendering"]
  end

  test "attributes are added, the class kept" do
    svg = Nokogiri::HTML5.fragment(pixel_icon("close", class: "toast__icon", data: { part: "x" })).at("svg")

    assert_equal "pixel-icon toast__icon", svg["class"]
    assert_equal "x", svg["data-part"]
  end

  test "an unknown name raises, a path never reaches the disk" do
    assert_raises(ShellHelper::UnknownPixelIcon) { pixel_icon("nothing-here") }
    assert_raises(ShellHelper::UnknownPixelIcon) { pixel_icon("../steam/sits_01") }
    assert_raises(ShellHelper::UnknownPixelIcon) { pixel_icon("") }
  end

  test "every exported icon inlines" do
    Dir[Rails.root.join("app/frontend/images/pixel/*.svg")].each do |path|
      assert_match(/\A<svg class="pixel-icon"/, pixel_icon(File.basename(path, ".svg")))
    end
  end

  test "a back-office page is one of the back_office controllers" do
    @controller_path = "back_office/import_runs"
    assert_predicate self, :back_office_page?

    @controller_path = "library"
    assert_not_predicate self, :back_office_page?
  end

  test "each screen's short name, by action or by controller; none for the hub or an unnamed screen" do
    names = {
      %w[library show] => "Sets", %w[library cards] => "Collection", %w[library set] => "Set", %w[cards show] => "Card", %w[boosters show] => "Capsule",
      %w[packs show] => "Capsule", %w[trades show] => "Trades", %w[trades edit] => "Trades", %w[friends show] => "Friends",
      %w[friend_profiles show] => "Profile", %w[public_profiles show] => "Profile", %w[public_profiles set] => "Set",
      %w[settings show] => "Profile", %w[feeds show] => "Feed", %w[pages legal] => "Legal notice", %w[pages how_it_works] => "How it works", %w[own_profiles show] => "My profile",
      %w[decks new] => "Deck", %w[decks show] => "Deck", %w[duels show] => "Duels",
      %w[market/orders new] => "Buy order", %w[market/my_orders show] => "My orders", %w[market/shops show] => "Shop",
      %w[market/archive_purchases new] => "Shop", %w[market/entrustments new] => "Entrust", %w[market/wanted_choices new] => "Entrust",
      %w[slot_purchases new] => "Slot",
      %w[back_office/dashboard show] => "Back-office", %w[back_office/import_runs index] => "Back-office",
      %w[pages home] => nil, %w[invite_links show] => nil
    }

    names.each do |(path, action), name|
      @controller_path, @action_name = path, action
      if name
        assert_equal name, shell_screen_label, "#{path}##{action}"
      else
        assert_nil shell_screen_label, "#{path}##{action}"
      end
    end
    I18n.with_locale(:fr) do
      @controller_path, @action_name = "cards", "show"
      assert_equal "Fiche", shell_screen_label
      @controller_path, @action_name = "pages", "legal"
      assert_equal "Mentions légales", shell_screen_label
    end
  end

  setup { controller.request.path_parameters[:locale] = "en" }

  def tabs_on(path, action)
    @controller_path, @action_name = path, action
    shell_tabs.to_h { |key, _icon, _path, current| [ key, current ] }
  end

  test "a player's five tabs, the trades tab leading to the kept sub-tab and DUELS to the Duels screen" do
    self.current_player = accounts_players(:player)
    @controller_path, @action_name = "pages", "home"

    tabs = shell_tabs
    assert_equal %i[hub booster sets trades duels], tabs.map(&:first)
    assert_equal %w[tab-hub tab-capsule tab-sets tab-trades tab-duels], tabs.map(&:second)
    assert_equal %w[/en /en/booster /en/library /en/exchanges /en/duels], tabs.map(&:third)
  end

  test "the trades and duels tabs are the page on their roots and current on their drill-downs" do
    self.current_player = accounts_players(:player)

    { %w[trades index] => "page", %w[markets show] => "page", %w[market/my_bids show] => "page", %w[market/my_sales show] => "page",
      %w[trades show] => "true", %w[trades new] => "true", %w[trades edit] => "true", %w[trades choose] => "true",
      %w[market/listings show] => "true", %w[market/shops show] => "true", %w[market/archive_purchases new] => "true",
      %w[pages home] => nil, %w[duels show] => nil }.each do |(path, action), current|
      assert_equal current.to_s, tabs_on(path, action)[:trades].to_s, "#{path}##{action}"
    end
    { %w[duels show] => "page", %w[decks new] => "true", %w[decks show] => "true", %w[trades index] => nil }.each do |(path, action), current|
      assert_equal current.to_s, tabs_on(path, action)[:duels].to_s, "#{path}##{action}"
    end
    assert_equal({ hub: "page", booster: nil, sets: nil, trades: nil, duels: nil }, tabs_on("feeds", "show"))
    assert_equal "page", tabs_on("cards", "show")[:sets]
    %w[grand_inventories pioneer_rankings brotherhood_sets].each { assert_equal "page", tabs_on(it, "show")[:sets], it }
    assert_equal "page", tabs_on("packs", "show")[:booster]
  end

  test "a visitor keeps two tabs, the page on their own screens" do
    tabs = shell_tabs
    assert_equal %i[landing all_cards], tabs.map(&:first)

    assert_equal({ landing: nil, all_cards: "page" }, tabs_on("cards", "show"))
    assert_equal({ landing: "page", all_cards: nil }, tabs_on("pages", "home"))
  end

  test "the Duels screen is a top-level screen for a player" do
    self.current_player = accounts_players(:player)
    @controller_path, @action_name = "duels", "show"

    assert_predicate self, :shell_top_level_screen?
  end

  test "the trades badge names both parts, either part alone, or nothing beyond the label" do
    assert_equal ", 2 trades and 1 auction to see", exchanges_badge_suffix(waiting: 2, outbid: 1)
    assert_equal ", 1 auction to see", exchanges_badge_suffix(waiting: 0, outbid: 1)
    assert_equal ", 3 trades to see", exchanges_badge_suffix(waiting: 3, outbid: 0)
    assert_equal "", exchanges_badge_suffix(waiting: 0, outbid: 0)
    I18n.with_locale(:fr) do
      assert_equal ", 2 échanges et 1 enchère à voir", exchanges_badge_suffix(waiting: 2, outbid: 1)
      assert_equal ", 1 enchère à voir", exchanges_badge_suffix(waiting: 0, outbid: 1)
      assert_equal ", 1 échange et 2 enchères à voir", exchanges_badge_suffix(waiting: 1, outbid: 2)
      assert_equal "", exchanges_badge_suffix(waiting: 0, outbid: 0)
    end
  end

  test "a count badge is its spoken words then its hidden number, nothing at zero" do
    badge = Nokogiri::HTML5.fragment(count_badge(1_200, ", 1,200 trades waiting", class: "exchanges-tabs__badge"))

    assert_equal [ "visually-hidden", "exchanges-tabs__badge" ], badge.children.map { it["class"] }
    assert_equal [ ", 1,200 trades waiting", "1,200" ], badge.children.map(&:text)
    assert_equal "true", badge.at_css(".exchanges-tabs__badge")["aria-hidden"]
    assert_nil count_badge(0, "", class: "exchanges-tabs__badge")
  end

  test "a visitor has no bank and zero games per tier, without a query" do
    assert_queries_count(0) do
      assert_nil shell_bank
      assert_equal({ 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0 }, shell_games_by_rarity)
    end
  end

  test "a player's reserve and games per tier are read once per request, the reserve alone" do
    self.current_player = accounts_players(:player)
    create_pack(current_player)
    Game::Holding.create!(player_id: current_player.id, card_season_id: catalog_card_seasons(:legendary_card_one).id, quantity: 2)

    assert_queries_count(2) do
      assert_equal({ available: 1, special: 0, openable: 1, reserve_full: false, next_available_at: nil, next_special_kind: nil }, shell_bank)
    end
    assert_equal 1, shell_games_by_rarity[5]
    assert_queries_count(0) do
      shell_bank
      shell_games_by_rarity
    end
  end

  test "the invitations waiting are read once per request, and not at all for a visitor" do
    assert_queries_count(0) { assert_nil shell_invitations_waiting }

    remove_instance_variable(:@shell_invitations_waiting)
    self.current_player = accounts_players(:player)
    Game::Invitation.create!(sender_id: accounts_players(:moderator).id, recipient_id: current_player.id)

    assert_queries_count(1) { assert_equal 1, shell_invitations_waiting }
    assert_queries_count(0) { assert_equal 1, shell_invitations_waiting }
  end

  test "the page's own bank is the shell's, without a query" do
    self.current_player = accounts_players(:player)
    @bank = { available: 4, reserve_full: false, next_available_at: nil }

    assert_queries_count(0) { assert_same @bank, shell_bank }
  end

  test "the version shown is the deploy's release tag, else the deployed commit, else dev" do
    assert_equal "v1.2.0", ShellHelper.app_version({ "GAMEBLE_VERSION" => "v1.2.0", "KAMAL_VERSION" => "0123456789abcdef" })
    assert_equal "0123456", ShellHelper.app_version({ "GAMEBLE_VERSION" => "", "KAMAL_VERSION" => "0123456789abcdef_uncommitted_abc" })
    assert_equal "dev", ShellHelper.app_version({})
    assert_equal ShellHelper.app_version, shell_version
  end

  test "the countdown to the next pack, unless the reserve is full" do
    bank = { available: 3, reserve_full: false, next_available_at: 90.seconds.from_now }
    assert_in_delta 90, shell_next_pack_in(bank), 1

    full = bank.merge(available: Game::Reserve::FULL, reserve_full: true)
    assert_nil shell_next_pack_in(full)
    assert_nil shell_next_pack_in(bank.merge(next_available_at: nil))
    assert_nil shell_next_pack_in(nil)
  end

  test "the remaining time reads hours from an hour, else minutes" do
    assert_equal "00:59", format_remaining(59)
    assert_equal "10:00", format_remaining(600)
    assert_equal "59:59", format_remaining(3599)
    assert_equal "1:00:00", format_remaining(3600)
    assert_equal "1:30:00", format_remaining(5400)
    assert_equal "24:00:00", format_remaining(86_400)
    assert_equal "00:00", format_remaining(-4)
  end

  test "chevron_icon draws the Lucide chevron-right, hidden from assistive tech, with its extra class" do
    svg = Nokogiri::HTML5.fragment(chevron_icon(class: "hub-linked__arrow")).at("svg")

    assert_equal "chevron-icon hub-linked__arrow", svg["class"]
    assert_equal "true", svg["aria-hidden"]
    assert_equal "m9 18 6-6-6-6", svg.at("path")["d"]
  end
end
