module Accounts
  # Claude's rewrite of a release's changes into a short French note, with the trail back to every commit:
  # each line names the commits it covers, each commit left out says why, and a commit Claude neither kept
  # nor dropped shows as forgotten. A line credits the contributors of the commits it covers.
  class CondensedChanges
    SECTIONS = ReleaseChanges::SECTIONS.keys.map(&:to_s).freeze
    ID_PREFIXES = { "features" => "f", "fixes" => "x" }.freeze
    LOCALE = :fr

    Source = Data.define(:id, :section, :change)
    Line = Data.define(:number, :section, :text, :sources) do
      def credits = sources.flat_map { it.change.credits }.uniq(&:downcase)
    end
    Review = Data.define(:source, :lines, :reason) do
      def kept? = lines.any?
      def dropped? = !kept? && reason.present?
      def forgotten? = !kept? && !dropped?
    end

    attr_reader :sources, :title, :intro, :lines, :reviews

    # The sources Claude reads, one per change, with the id its answer refers to.
    def self.sources_of(changes)
      SECTIONS.flat_map do |section|
        changes.public_send(section).map.with_index(1) { |change, index| Source.new(id: "#{ID_PREFIXES.fetch(section)}#{index}", section:, change:) }
      end
    end

    # The answer is { "title", "intro", "lines" => [{ "section", "text", "sources" }], "dropped" => [{ "source", "reason" }] }.
    def initialize(changes, answer)
      @sources = self.class.sources_of(changes)
      by_id = @sources.index_by(&:id)
      @title = answer["title"].to_s.squish
      @intro = answer["intro"].to_s.squish
      @lines = lines_of(answer["lines"], by_id)
      @reviews = reviews_of(answer["dropped"])
    end

    def body
      blocks = [ intro.presence ]
      SECTIONS.each do |section|
        section_lines = lines.select { it.section == section }
        next if section_lines.empty?

        items = section_lines.map { "- #{line_text(it)}" }
        blocks << "## #{I18n.t("release_notes.sections.#{section}", locale: LOCALE)}\n#{items.join("\n")}"
      end
      blocks.compact.join("\n\n")
    end

    def fitting?
      title.length <= ReleaseNote::TITLE_LENGTH && body.length <= ReleaseNote::BODY_LENGTH
    end

    def forgotten
      reviews.select(&:forgotten?)
    end

    private

    def lines_of(answered, by_id)
      Array(answered).filter_map do |line|
        section = line["section"].to_s
        text = line["text"].to_s.squish.delete_prefix("- ").strip
        next unless SECTIONS.include?(section) && text.present?

        [ section, text, Array(line["sources"]).filter_map { by_id[it.to_s] }.uniq ]
      end.sort_by.with_index { |(section), index| [ SECTIONS.index(section), index ] }.each.with_index(1).map do |(section, text, sources), number|
        Line.new(number:, section:, text:, sources:)
      end
    end

    def reviews_of(dropped)
      reasons = Array(dropped).to_h { [ it["source"].to_s, it["reason"].to_s.squish ] }
      sources.map do |source|
        Review.new(source:, lines: lines.select { it.sources.include?(source) }.map(&:number), reason: reasons[source.id])
      end
    end

    def line_text(line)
      return line.text if line.credits.empty?

      I18n.t("release_notes.credited", locale: LOCALE, change: line.text, people: line.credits.map { "@#{it}" }.join(", "))
    end
  end
end
