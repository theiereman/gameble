module Catalog
  # The epics of the initiative's ticket file (a TOML file whose `[[epic]]`
  # entries carry a `slug` and a `title`), in the file's order, for the
  # roadmap milestones. A missing or broken file is a reading with a problem,
  # never an exception: the roadmap stays as it is.
  #
  #   Catalog::InitiativeEpics.read(path)
  #   # => Reading(epics: [ Epic(slug: "epic-steam-catalog", title: "Steam catalog"), … ], problem: nil)
  #   # => Reading(epics: nil, problem: "missing: …")
  module InitiativeEpics
    Epic = Data.define(:slug, :title)
    Reading = Data.define(:epics, :problem)

    def self.read(path)
      epics_of(Tomlrb.load_file(path.to_s))
    rescue Errno::ENOENT
      unread("missing: #{path}")
    rescue SystemCallError => error
      unread("unreadable: #{path}: #{error.message}")
    rescue StandardError => error
      unread("unparseable: #{path}: #{error.message}")
    end

    def self.epics_of(document)
      entries = document["epic"]
      return unread("no epic in the file") unless entries.is_a?(Array) && entries.any?
      return unread("an epic has no slug") unless entries.all? { |entry| entry.is_a?(Hash) && entry["slug"].is_a?(String) && entry["slug"].present? }

      Reading.new(epics: entries.map { |entry| Epic.new(slug: entry["slug"], title: entry["title"].to_s.squish.presence || entry["slug"]) }, problem: nil)
    end
    private_class_method :epics_of

    def self.unread(problem)
      Reading.new(epics: nil, problem:)
    end
    private_class_method :unread
  end
end
