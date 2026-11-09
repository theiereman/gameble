module Accounts
  # The commits between two tags, sorted into the new features and the fixes a release note's first draft lists,
  # each crediting the contributors who wrote it.
  class ReleaseChanges
    CONVENTIONAL = /\A(?<type>[a-z]+)(?:\([^)]*\))?!?:\s*(?<subject>.+)\z/
    SECTIONS = { features: "feat", fixes: "fix" }.freeze

    Change = Data.define(:subject, :credits)

    attr_reader :since, :head, :features, :fixes

    # Each commit is { subject:, credits: [GitHub logins] }.
    def initialize(since:, head:, commits:)
      @since = since
      @head = head
      @features, @fixes = SECTIONS.values.map do |type|
        commits.filter_map { change_of(it, type) }
      end
    end

    def empty?
      features.empty? && fixes.empty?
    end

    def draft_body(locale)
      SECTIONS.keys.filter_map do |section|
        changes = public_send(section)
        next if changes.empty?

        "## #{I18n.t("release_notes.sections.#{section}", locale:)}\n#{changes.map { "- #{line(it, locale)}" }.join("\n")}"
      end.join("\n\n")
    end

    private

    def change_of(commit, type)
      match = CONVENTIONAL.match(commit[:subject].to_s.strip)
      return unless match && match[:type] == type

      Change.new(subject: match[:subject].sub(/\A\p{Lower}/, &:upcase), credits: Array(commit[:credits]).uniq)
    end

    def line(change, locale)
      return change.subject if change.credits.empty?

      I18n.t("release_notes.credited", locale:, change: change.subject, people: change.credits.map { "@#{it}" }.join(", "))
    end
  end
end
