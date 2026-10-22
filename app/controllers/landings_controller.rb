class LandingsController < ApplicationController
  include PublicRead

  def show
    authorize :landing, :show?
    return redirect_to(home_path, status: :see_other) if current_player

    @samples = Catalog::LandingSampleCards.call(locale: I18n.locale)
    @roadmap = Catalog::LandingRoadmap.call(locale: I18n.locale)
    @season_facts = readable { Game::LandingSeasonFacts.call(locale: I18n.locale) }
    @goal = readable { Game::LandingGoal.call(locale: I18n.locale) }
  end

  private

  def readable
    yield
  rescue ActiveRecord::ActiveRecordError => error
    Rails.logger.error("landing block unreadable: #{error.class}")
    nil
  end
end
