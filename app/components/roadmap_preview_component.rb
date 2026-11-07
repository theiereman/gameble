class RoadmapPreviewComponent < ViewComponent::Base
  def initialize(draft:, locale:)
    @draft = draft
    @locale = locale.to_s
  end

  def call
    tag.div(class: "landing", lang: @locale) do
      I18n.with_locale(@locale) do
        render("landings/roadmap", milestones: Catalog::LandingRoadmap.preview(@draft, locale: @locale))
      end
    end
  end
end
