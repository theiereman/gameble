require "test_helper"
require_relative "../../support/supporters"

class Game::SupporterStatusTest < ActiveSupport::TestCase
  include Supporters

  test "the supporters among many players are read in one query" do
    supporter = accounts_players(:player)
    other = accounts_players(:moderator)
    grant_supporter(supporter)

    supporters = nil
    assert_queries_count(1) { supporters = Game::SupporterStatus.for_players([ supporter, other, nil, supporter ]) }
    assert_equal Set[supporter.id], supporters
  end

  test "no player asks nothing" do
    assert_queries_count(0) { assert_equal Set.new, Game::SupporterStatus.for_players([]) }
    assert_queries_count(0) { assert_equal Set.new, Game::SupporterStatus.for_players([ nil ]) }
  end
end
