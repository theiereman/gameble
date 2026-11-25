require "test_helper"

class FeedHelperTest < ActionView::TestCase
  include PublicProfilesHelper

  def entry(kind, tier: nil) = Game::FeedEntry.new(kind:, tier:)

  test "the decor behind an entry is its kind, a completed set getting a decor of its own" do
    assert_equal "pull", feed_decor(entry("pull"))
    assert_equal "sale", feed_decor(entry("sale"))
    assert_equal "set", feed_decor(entry("set", tier: "gold"))
    assert_equal "set-complete", feed_decor(entry("set", tier: Catalog::SetTier::COMPLETE))
  end

  test "the ticker's sentence puts a supporter's VIP badge after their name, never a nameless supporter's" do
    card = Data.define(:id, :title).new(id: "portal", title: "Portal")
    pull = ->(name, supporter) { Game::FeedEntries::Entry.new(entry: entry("pull"), player: Accounts::Player.new(persona_name: name), filler: false, player_supporter: supporter) }

    @rendered = feed_sentence(pull.("Hugo", true), card, links: false)
    assert_select "strong + .supporter-badge--compact", "VIP"
    assert_select "strong", "Hugo"

    @rendered = feed_sentence(pull.("Hugo", false), card, links: false)
    assert_select ".supporter-badge", 0

    @rendered = feed_sentence(pull.("", true), card, links: false)
    assert_select ".supporter-badge", 0
  end

  test "a sale names a supporter buyer with the VIP badge after their name, any other buyer without" do
    card = Data.define(:id, :title).new(id: "portal", title: "Portal")
    sale = lambda do |supporter|
      Game::FeedEntries::Entry.new(entry: entry("sale"), player: Accounts::Player.new(persona_name: "Hugo"), filler: false, price: 900,
        player_supporter: supporter)
    end

    @rendered = feed_sentence(sale.(true), card, links: false)
    assert_select ".player-name-group span.player-name + .supporter-badge--compact", "VIP"

    @rendered = feed_sentence(sale.(false), card, links: false)
    assert_select ".supporter-badge", 0
  end
end
