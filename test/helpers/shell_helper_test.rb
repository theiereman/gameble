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

  test "a visitor has no bank and zero copies per tier, without a query" do
    assert_queries_count(0) do
      assert_nil shell_bank
      assert_equal({ 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0 }, shell_tier_counts)
    end
  end

  test "a player's bank and tier counts are read once per request" do
    self.current_player = accounts_players(:player)
    create_pack(current_player)
    Game::Holding.create!(player_id: current_player.id, card_season_id: catalog_card_seasons(:gold_card_one).id, quantity: 2)

    assert_equal 1, shell_bank[:available]
    assert_equal 2, shell_tier_counts[5]
    assert_queries_count(0) do
      shell_bank
      shell_tier_counts
    end
  end

  test "the countdown to the next pack, unless the reserve is full" do
    bank = { available: 3, next_available_at: 90.seconds.from_now, bonus_collectable: false }
    assert_in_delta 90, shell_next_pack_in(bank), 1
    assert_not shell_reserve_full?(bank)

    full = bank.merge(available: Game::Pack::BANK_SIZE)
    assert shell_reserve_full?(full)
    assert_nil shell_next_pack_in(full)
    assert_nil shell_next_pack_in(bank.merge(next_available_at: nil))
    assert_nil shell_next_pack_in(nil)
  end
end
