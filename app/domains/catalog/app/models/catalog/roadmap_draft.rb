module Catalog
  # The roadmap as staff edit it: milestones and their stories, in order,
  # each row under the key the form gave it. Built from what a form sent
  # or from the saved rows, it knows which rows it refuses and why.
  class RoadmapDraft
    DEFAULT_STATUS = "to_come".freeze

    Entry = Data.define(:key, :token, :wording_fr, :wording_en, :status, :shown, :stories) do
      def attributes
        { wording_fr: RoadmapWording.clean(wording_fr), wording_en: RoadmapWording.clean(wording_en), status:, shown: }
      end

      def refusal
        return :invalid_wording unless attributes.values_at(:wording_fr, :wording_en).all? { RoadmapWording.valid?(it) }

        :invalid_status unless RoadmapMilestone::STATUSES.include?(status)
      end
    end

    attr_reader :milestones

    def self.from_form(sent)
      new(rows(sent).map { |key, row| entry(key, row, stories: rows(row["stories"]).map { |story_key, story| entry(story_key, story) }) })
    end

    def self.from_records(milestones)
      new(milestones.map { |milestone| entry_of(milestone, stories: milestone.stories.sort_by { [ it.position, it.id ] }.map { entry_of(it) }) })
    end

    def self.blank_entry(key)
      Entry.new(key:, token: nil, wording_fr: nil, wording_en: nil, status: DEFAULT_STATUS, shown: true, stories: [])
    end

    def self.rows(sent)
      sent.respond_to?(:each_pair) ? sent.each_pair.select { |key, row| key.is_a?(String) && row.respond_to?(:each_pair) } : []
    end

    def self.entry(key, row, stories: [])
      Entry.new(key:, token: string(row["token"]).presence, wording_fr: string(row["wording_fr"]), wording_en: string(row["wording_en"]),
        status: string(row["status"]), shown: row["shown"] == "1", stories:)
    end

    def self.entry_of(record, stories: [])
      Entry.new(key: record.token, token: record.token, wording_fr: record.wording_fr, wording_en: record.wording_en,
        status: record.status, shown: record.shown, stories:)
    end

    def self.string(value) = value.is_a?(String) ? value : nil

    private_class_method :rows, :entry, :entry_of, :string

    def initialize(milestones)
      @milestones = milestones
    end

    def entries
      milestones.flat_map { [ it, *it.stories ] }
    end

    # Row key => failure code, for every row the draft refuses.
    def refusals
      @refusals ||= entries.to_h { [ it.key, it.refusal || repeated(it) ] }.compact
    end

    def valid?
      refusals.empty?
    end

    private

    def repeated(entry)
      :duplicate_row if entry.token && entries.count { it.token == entry.token } > 1
    end
  end
end
