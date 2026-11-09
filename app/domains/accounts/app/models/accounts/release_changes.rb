module Accounts
  # The commits between two tags, sorted into the new features and the fixes a release note's first draft lists.
  class ReleaseChanges
    CONVENTIONAL = /\A(?<type>[a-z]+)(?:\([^)]*\))?!?:\s*(?<subject>.+)\z/
    SECTIONS = { features: "feat", fixes: "fix" }.freeze

    attr_reader :since, :head, :features, :fixes

    def initialize(since:, head:, subjects:)
      @since = since
      @head = head
      changes = subjects.filter_map { CONVENTIONAL.match(it.to_s.strip) }
      @features, @fixes = SECTIONS.values.map do |type|
        changes.select { it[:type] == type }.map { it[:subject].sub(/\A\p{Lower}/, &:upcase) }
      end
    end

    def empty?
      features.empty? && fixes.empty?
    end

    def draft_body(locale)
      SECTIONS.keys.filter_map do |section|
        items = public_send(section)
        next if items.empty?

        "## #{I18n.t("release_notes.sections.#{section}", locale:)}\n#{items.map { "- #{it}" }.join("\n")}"
      end.join("\n\n")
    end
  end
end
