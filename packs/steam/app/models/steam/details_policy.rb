module Steam
  # What can become a card (catalog-and-rarity.md, Inclusion and Card
  # identity; epic 2 R3, R4): turns the English and French GetItems store
  # items of a kept game into the details stored on its Steam::App and the
  # details step's verdict.
  #
  #   Steam::DetailsPolicy.verdict(620, english_item, french_item)
  #   # => #<data Steam::DetailsPolicy::Verdict name_en: "Portal 2", ..., exclusion: nil>
  #
  # Availability and type come from the English item alone. The French item
  # gives the French name and short description; when it is missing,
  # unsuccessful or blank, the English value stands in. The first exclusion
  # that matches wins, in the order of EXCLUSIONS.
  module DetailsPolicy
    UNAVAILABLE = "unavailable".freeze
    NOT_A_GAME = "not_a_game".freeze
    NO_TITLE = "no_title".freeze
    NO_VERTICAL_IMAGE = "no_vertical_image".freeze
    NO_RELEASE_DATE = "no_release_date".freeze
    EXCLUSIONS = [ UNAVAILABLE, NOT_A_GAME, NO_TITLE, NO_VERTICAL_IMAGE, NO_RELEASE_DATE ].freeze

    # Steam's store item type of a game (EStoreAppType).
    GAME_TYPE = 0
    RELEASE_DATES = %w[original_release_date original_steam_release_date steam_release_date].freeze

    Verdict = Data.define(:name_en, :name_fr, :short_description_en, :short_description_fr, :publishers, :release_on,
      :tag_ids, :store_url_path, :image_url, :details, :exclusion) do
      def kept?
        exclusion.nil?
      end

      # The columns of steam_apps this verdict sets.
      def attributes
        to_h.except(:exclusion).merge(details_exclusion: exclusion)
      end
    end

    def self.verdict(appid, english, french)
      english = nil unless english.is_a?(Hash) && english["success"] == 1
      french = nil unless french.is_a?(Hash) && french["success"] == 1
      return unavailable unless english

      name_en = english["name"].to_s.strip.presence
      description_en = PlainText.call(english.dig("basic_info", "short_description")).presence
      details = Verdict.new(
        name_en: name_en,
        name_fr: french&.dig("name").to_s.strip.presence || name_en,
        short_description_en: description_en,
        short_description_fr: PlainText.call(french&.dig("basic_info", "short_description")).presence || description_en,
        publishers: publishers(english),
        release_on: release_on(english),
        tag_ids: tag_ids(english),
        store_url_path: english["store_url_path"].to_s.presence || "app/#{appid}/",
        image_url: Cdn.asset_url(english.dig("assets", "asset_url_format"), english.dig("assets", "library_capsule")),
        details: english.merge("french" => { "name" => french&.dig("name"), "short_description" => french&.dig("basic_info", "short_description") }),
        exclusion: nil
      )
      details.with(exclusion: exclusion(english, details))
    end

    def self.unavailable
      Verdict.new(name_en: nil, name_fr: nil, short_description_en: nil, short_description_fr: nil, publishers: nil, release_on: nil,
        tag_ids: nil, store_url_path: nil, image_url: nil, details: nil, exclusion: UNAVAILABLE)
    end

    def self.exclusion(english, details)
      if english["type"] != GAME_TYPE then NOT_A_GAME
      elsif details.name_en.nil? then NO_TITLE
      elsif details.image_url.nil? then NO_VERTICAL_IMAGE
      elsif details.release_on.nil? then NO_RELEASE_DATE
      end
    end

    def self.publishers(item)
      Array(item.dig("basic_info", "publishers")).filter_map { |publisher| publisher["name"].to_s.strip.presence if publisher.is_a?(Hash) }
    end

    # The earliest known date: a game released before Steam keeps its
    # original date, which the dust uses.
    def self.release_on(item)
      release = item["release"].is_a?(Hash) ? item["release"] : {}
      timestamps = RELEASE_DATES.map { |key| release[key].to_i }.select(&:positive?)
      timestamps.min&.then { |timestamp| Time.at(timestamp).utc.to_date }
    end

    # The tagids by weight, the heaviest first, ties by tagid.
    def self.tag_ids(item)
      Array(item["tags"]).select { |tag| tag.is_a?(Hash) && tag["tagid"].present? }
        .sort_by { |tag| [ -tag["weight"].to_i, tag["tagid"].to_i ] }
        .map { |tag| tag["tagid"].to_i }
    end

    private_class_method :unavailable, :exclusion, :publishers, :release_on, :tag_ids
  end
end
