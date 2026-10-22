class RoadmapsController < ApplicationController
  include PublicRead

  def show
    authorize :roadmap, :show?

    @milestones = Catalog::PublicRoadmap.call(locale: I18n.locale)
  end
end
