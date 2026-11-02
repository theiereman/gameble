class RoadmapsController < ApplicationController
  include PublicRead
  include MarkdownNegotiation

  negotiates_markdown only: :show

  def show
    authorize :roadmap, :show?

    @milestones = Catalog::PublicRoadmap.call(locale: I18n.locale)
    render_markdown if markdown_requested?
  end
end
