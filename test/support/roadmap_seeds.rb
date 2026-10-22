module RoadmapSeeds
  def create_roadmap_milestones(*slugs)
    epics = slugs.map { Catalog::InitiativeEpics::Epic.new(slug: it, title: it.titleize) }
    Catalog::CreateRoadmapMilestones.new.call(epics:).value!
  end

  def show_roadmap_milestone(milestone, status: "to_come", shown: true)
    Catalog::UpdateRoadmapMilestone.new.call(milestone:, wording_fr: "Étape #{milestone.epic_slug}", wording_en: "Step #{milestone.epic_slug}", status:, shown:).value!
  end

  def add_roadmap_story(milestone, name, status: "to_come", shown: true)
    Catalog::CreateRoadmapStory.new.call(milestone:, wording_fr: "Récit #{name}", wording_en: "Story #{name}", status:, shown:).value!
  end

  def seed_roadmap(stories:)
    shown = create_roadmap_milestones("alpha", "beta", "gamma", "delta").first(3)
    shown.zip(%w[done in_progress to_come]).each { |milestone, status| show_roadmap_milestone(milestone, status:) }
    stories.each { |name, status, visible| add_roadmap_story(shown.first, name, status:, shown: visible) }
    shown
  end
end
