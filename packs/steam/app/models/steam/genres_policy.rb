module Steam
  # Turns the store's appdetails answer for a detailed game into its genres,
  # its credit (the legal notice) and the genres step's verdict (epic 2 R4,
  # R7).
  #
  #   Steam::GenresPolicy.verdict(620, { "success" => true, "data" => {...} })
  #   # => #<data Steam::GenresPolicy::Verdict genres: ["action", "adventure"], credit: "...", app_details: {...}, exclusion: nil>
  #
  # Genres are keys (each description parameterized with `_`, Steam's order
  # kept); a game without genres gets `[]` and sits in no tome. The store
  # refusing the app, or answering for another app, makes it unavailable.
  module GenresPolicy
    UNAVAILABLE = "unavailable".freeze
    EXCLUSIONS = [ UNAVAILABLE ].freeze
    CREDIT_LIMIT = 1_000

    Verdict = Data.define(:genres, :credit, :app_details, :exclusion) do
      def kept?
        exclusion.nil?
      end

      # The columns of steam_apps this verdict sets.
      def attributes
        to_h.except(:exclusion).merge(genres_exclusion: exclusion)
      end
    end

    # An unavailable game keeps genres, credit and data NULL: not fetched.
    def self.verdict(appid, entry)
      data = entry["data"] if entry.is_a?(Hash)
      data = nil unless data.is_a?(Hash)
      unless entry.is_a?(Hash) && entry["success"] == true && data && data["steam_appid"].to_i == appid
        return Verdict.new(genres: nil, credit: nil, app_details: nil, exclusion: UNAVAILABLE)
      end

      Verdict.new(genres: genres(data), credit: credit(data), app_details: data, exclusion: nil)
    end

    def self.genres(data)
      Array(data["genres"]).filter_map { |genre| genre["description"].to_s.parameterize(separator: "_").presence if genre.is_a?(Hash) }.uniq
    end

    def self.credit(data)
      PlainText.call(data["legal_notice"]).truncate(CREDIT_LIMIT, separator: " ", omission: "…").presence
    end

    private_class_method :genres, :credit
  end
end
