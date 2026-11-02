class LandingMarkdown
  STEPS = %w[join accumulate discover grow].freeze
  NOTES = %w[rarities alive seasons].freeze
  FACTS = %w[players packs discoveries].freeze

  def initialize(samples:, odds:, roadmap:, season_facts:, links:)
    @samples = samples
    @odds = odds
    @roadmap = roadmap
    @season_facts = season_facts
    @links = links
  end

  def to_s
    [ hero, concept, how, live, roadmap, free, footer ].join("\n\n").concat("\n")
  end

  private
    def hero
      [ "# #{t("hero.hook")}", t("hero.line") ].join("\n\n")
    end

    def concept
      [ "## #{t("concept.title")}", t("concept.subtitle"), rarities, notes ].join("\n\n")
    end

    def rarities
      @odds.map do |row|
        entry = "#{I18n.t("catalog.rarity.#{row.key}")}, #{t("concept.per_card", percent: row.percent)}"
        card = @samples[row.key]
        card ? "- #{entry} (#{card.title})" : "- #{entry}"
      end.join("\n")
    end

    def notes
      NOTES.map { "- **#{t("concept.notes.#{it}.title")}**: #{t("concept.notes.#{it}.text")}" }.join("\n")
    end

    def how
      steps = STEPS.each_with_index.map { |step, index| "#{index + 1}. **#{t("how.#{step}.title")}**: #{t("how.#{step}.text")}" }
      [ "## #{t("how.title")}", t("how.subtitle"), steps.join("\n") ].join("\n\n")
    end

    def live
      return "## #{t("live.title")}" if @season_facts.nil?

      facts = FACTS.map { "- #{t("live.facts.#{it}")}: #{ActiveSupport::NumberHelper.number_to_delimited(@season_facts[it.to_sym])}" }
      season = t("live.season_name", number: @season_facts[:season_number]) if @season_facts[:season_number]
      [ "## #{t("live.title")}", season, facts.join("\n") ].compact.join("\n\n")
    end

    def roadmap
      milestones = @roadmap.map do |milestone|
        stories = milestone.stories.map { "  - #{it.wording} (#{t("roadmap.statuses.#{it.status}")})" }
        [ "- #{milestone.wording} (#{t("roadmap.statuses.#{milestone.status}")})", *stories ].join("\n")
      end
      [ "## #{t("roadmap.title")}", t("roadmap.subtitle"), milestones.join("\n") ].compact_blank.join("\n\n")
    end

    def free
      [ "## #{t("free.title")}", t("free.open"), t("free.respect") ].join("\n\n")
    end

    def footer
      @links.map { |label, url| "- [#{label}](#{url})" }.join("\n")
    end

    def t(key, **options)
      I18n.t("landings.show.#{key}", **options)
    end
end
