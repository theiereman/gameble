namespace :catalog do
  # Meant for production: run once after the deploy that adds
  # catalog_card_seasons.number (AD-28, the expand step), before the
  # migration that makes it NOT NULL for published card-seasons.
  desc "Numbers the cards of every published season that has no numbers yet (Catalog::PublishSeason#number_published); idempotent"
  task number_seasons: :environment do
    Catalog::Season.published.order(:number).pluck(:number).each do |number|
      result = Catalog::PublishSeason.new.number_published(number:)
      if result.success?
        puts "catalog:number_seasons: season #{number} numbered"
      elsif result.failure == :already_numbered
        puts "catalog:number_seasons: season #{number} already numbered"
      else
        abort "catalog:number_seasons: season #{number} failed: #{result.failure}"
      end
    end
  end

  # Run on every boot of a web container (bin/docker-entrypoint), after
  # db:prepare. It never fails the boot: a missing or broken file, or any
  # other error, is a warning and leaves the roadmap as it is.
  desc "Creates a hidden roadmap milestone for each initiative epic that has none (Catalog::CreateRoadmapMilestones); idempotent"
  task create_roadmap_milestones: :environment do
    reading = Catalog::InitiativeEpics.read(Rails.root.join("_bmad-output/initiative-gameble/tickets.toml"))
    if reading.problem
      warn "catalog:create_roadmap_milestones: the initiative's epics could not be read (#{reading.problem}); no milestone created"
      next
    end

    result = Catalog::CreateRoadmapMilestones.new.call(epics: reading.epics)
    if result.failure?
      warn "catalog:create_roadmap_milestones: failed: #{result.failure}; no milestone created"
    elsif result.value!.empty?
      puts "catalog:create_roadmap_milestones: every epic has its milestone; nothing created"
    else
      puts "catalog:create_roadmap_milestones: #{result.value!.size} milestones created: #{result.value!.map(&:epic_slug).join(", ")}"
    end
  rescue StandardError => error
    warn "catalog:create_roadmap_milestones: failed: #{error.class}: #{error.message}; no milestone created"
  end
end
