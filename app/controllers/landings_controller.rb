class LandingsController < ApplicationController
  include PublicRead

  def show
    authorize :landing, :show?
    return redirect_to(home_path, status: :see_other) if current_player

    @samples = Catalog::LandingSampleCards.call(locale: I18n.locale)
    @roadmap = Catalog::LandingRoadmap.call(locale: I18n.locale)
  end
end
