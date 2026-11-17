require "test_helper"
require_relative "../support/live_duels"

class PlayerStreamDuelBadgeTest < ActiveSupport::TestCase
  include ActionCable::TestHelper
  include LiveDuels

  setup do
    @lea = accounts_players(:player)
    @hugo = accounts_players(:moderator)
    @hugo.update!(persona_name: "Hugo")
    befriend(@lea, @hugo)
    complete_deck(@lea, "Lea")
    complete_deck(@hugo, "Hugo")
  end

  def update_in(player, locale, target)
    fragment = Nokogiri::HTML5.fragment(ActiveSupport::JSON.decode(broadcasts(PlayerStream.name(player, locale)).sole))
    stream = fragment.at_css("turbo-stream[action=update][target=#{target}]")
    Nokogiri::HTML5.fragment(stream.at_css("template").inner_html)
  end

  test "a duel in progress puts a badge of 1 on the DUELS tab and menu 04, named in both locales" do
    start_duel(@lea, @hugo)

    PlayerStreamJob.perform_now([ { player_id: @hugo.id, topic: "duels" } ])

    %w[tab-duels-badge menu-duels-badge].each do |target|
      assert_equal "1", update_in(@hugo, :en, target).at_css("[aria-hidden=true]").text
      assert_equal ", 1 duel in progress", update_in(@hugo, :en, target).at_css(".visually-hidden").text
      assert_equal ", 1 duel en cours", update_in(@hugo, :fr, target).at_css(".visually-hidden").text
    end
  end

  test "a finished duel takes the badge away" do
    duel = start_duel(@lea, @hugo)
    10.times { duel = play_round(duel) }

    PlayerStreamJob.perform_now([ { player_id: @hugo.id, topic: "duels" } ])

    assert_empty update_in(@hugo, :en, "tab-duels-badge").text.strip
  end
end
