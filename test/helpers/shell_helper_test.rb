require "test_helper"
require_relative "../support/game_packs"

# The shell's helpers (story 8.1): pixel icons inlined, the back-office
# switch, and the top bar's figures read once per request.
class ShellHelperTest < ActionView::TestCase
  include GamePacks

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
      %w[library show] => "Collection", %w[library set] => "Set", %w[cards show] => "Card", %w[boosters show] => "Booster",
      %w[packs show] => "Booster", %w[trades show] => "Trades", %w[trades edit] => "Trades", %w[friends show] => "Friends",
      %w[friend_profiles show] => "Profile", %w[public_profiles show] => "Profile", %w[public_profiles set] => "Set",
      %w[settings show] => "Profile", %w[feeds show] => "Feed", %w[pages legal] => "Legal notice", %w[pages how_it_works] => "How it works", %w[pages more] => "More",
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

  test "a visitor has no bank and zero copies per tier, without a query" do
    assert_queries_count(0) do
      assert_nil shell_bank
      assert_equal({ 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0 }, shell_tier_counts)
    end
  end

  test "a player's reserve and tier counts are read once per request, the reserve alone" do
    self.current_player = accounts_players(:player)
    create_pack(current_player)
    Game::Holding.create!(player_id: current_player.id, card_season_id: catalog_card_seasons(:legendary_card_one).id, quantity: 2)

    assert_queries_count(2) do
      assert_equal({ available: 1, reserve_full: false, next_available_at: nil }, shell_bank)
    end
    assert_equal 2, shell_tier_counts[5]
    assert_queries_count(0) do
      shell_bank
      shell_tier_counts
    end
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
end
