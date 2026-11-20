require "test_helper"
require_relative "../../support/game_packs"

# No duel grants a capsule during the alpha, but the duel pack kind keeps its schema for the beta: one duel capsule per
# player and UTC day, three cards, and a duel day on duel packs only.
class Game::DuelPackSchemaTest < ActiveSupport::TestCase
  include GamePacks

  setup do
    @lea = accounts_players(:player)
    @hugo = accounts_players(:moderator)
  end

  test "the unique index refuses a second duel capsule of the same player and day" do
    create_pack(@lea, kind: :duel, available_at: Time.current)

    assert_raises(ActiveRecord::RecordNotUnique) { create_pack(@lea, kind: :duel, available_at: Time.current) }
    assert create_pack(@hugo, kind: :duel, available_at: Time.current)
    assert create_pack(@lea, kind: :duel, available_at: 1.day.from_now)
  end

  test "the checks refuse an unknown kind, a duel capsule of the wrong size and a duel day on any other kind" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Game::Pack.insert!(Game::Pack.row(player_id: @lea.id, kind: :mystery, season_id: catalog_seasons(:one).id,
        card_season_ids: [ catalog_card_seasons(:portal_one).id ] * 3, available_at: Time.current))
    end
    assert_raises(ActiveRecord::StatementInvalid) { create_pack(@lea, kind: :duel, cards: [ catalog_card_seasons(:portal_one).id ] * 5) }
    assert_raises(ActiveRecord::StatementInvalid) { create_pack(@lea, kind: :bonus, duel_day: Date.current) }
    assert_raises(ActiveRecord::StatementInvalid) { create_pack(@lea, kind: :duel, duel_day: nil) }
  end
end
