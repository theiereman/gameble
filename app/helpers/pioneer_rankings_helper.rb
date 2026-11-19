module PioneerRankingsHelper
  def pioneer_boards(inventory_scope, viewer)
    now = Time.current
    [ :week, :season ].map do |choice|
      Game::PioneerBoard.board(Game::PioneerBoard.period_for(choice, inventory_scope), viewer:, now:)
    end
  end

  def pioneer_rank(rank)
    t("pioneer_rankings.rank", count: rank)
  end

  def pioneer_place_words(place)
    t("pioneer_rankings.place", rank: pioneer_rank(place.rank), count: place.count)
  end

  def pioneer_ranking_params(period_choice, scope)
    { period: ("season" unless period_choice == :week), seasons: ("current" if scope == :current) }.compact
  end
end
