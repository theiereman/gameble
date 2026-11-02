module RoadmapSeeds
  def create_roadmap_milestones(*names)
    names.map do |name|
      Catalog::RoadmapMilestone.create!(wording_fr: "Étape #{name}", wording_en: "Step #{name}", status: "to_come", shown: false,
        position: Catalog::RoadmapMilestone.maximum(:position).to_i + 1)
    end
  end

  def show_roadmap_milestone(milestone, status: "to_come", shown: true)
    milestone.update!(status:, shown:)
  end

  def add_roadmap_story(milestone, name, status: "to_come", shown: true)
    Catalog::RoadmapStory.create!(milestone:, wording_fr: "Récit #{name}", wording_en: "Story #{name}", status:, shown:,
      position: Catalog::RoadmapStory.where(milestone:).maximum(:position).to_i + 1)
  end

  def seed_roadmap(stories:)
    shown = create_roadmap_milestones("alpha", "beta", "gamma", "delta").first(3)
    shown.zip(%w[done in_progress to_come]).each { |milestone, status| show_roadmap_milestone(milestone, status:) }
    stories.each { |name, status, visible| add_roadmap_story(shown.first, name, status:, shown: visible) }
    shown
  end
end
