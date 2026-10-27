module Steam
  module DetailsPolicy
    UNAVAILABLE = "unavailable".freeze
    NOT_A_GAME = "not_a_game".freeze
    NO_TITLE = "no_title".freeze
    NO_VERTICAL_IMAGE = "no_vertical_image".freeze
    NO_RELEASE_DATE = "no_release_date".freeze
    EXCLUSIONS = [ UNAVAILABLE, NOT_A_GAME, NO_TITLE, NO_VERTICAL_IMAGE, NO_RELEASE_DATE ].freeze

    GAME_TYPE = 0
    RELEASE_DATES = %w[original_release_date original_steam_release_date steam_release_date].freeze

    Verdict = Data.define(:name_en, :name_fr, :short_description_en, :short_description_fr, :publishers, :release_on,
      :tag_ids, :store_url_path, :image_url, :details, :exclusion) do
      def kept?
        exclusion.nil?
      end

      def attributes
        to_h.except(:exclusion).merge(details_exclusion: exclusion)
      end
    end

    def self.verdict(appid, english, french)
      english = nil unless english.is_a?(Hash) && english["success"] == 1
      french = nil unless french.is_a?(Hash) && french["success"] == 1
      return unavailable unless english

      name_en = text(english["name"])
      description_en = description(english)
      assets = RawValue.object(english["assets"])
      details = Verdict.new(
        name_en: name_en,
        name_fr: text(french&.fetch("name", nil)) || name_en,
        short_description_en: description_en,
        short_description_fr: description(french) || description_en,
        publishers: publishers(english),
        release_on: earliest_release_on(english),
        tag_ids: tag_ids_by_weight(english),
        store_url_path: RawValue.string(english["store_url_path"]).presence || "app/#{appid}/",
        image_url: Cdn.asset_url(RawValue.string(assets["asset_url_format"]), RawValue.string(assets["library_capsule"])),
        details: RawValue.scrub(english.merge("french" => {
          "name" => french&.fetch("name", nil), "short_description" => RawValue.object(french&.fetch("basic_info", nil))["short_description"]
        })),
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

    def self.text(value)
      RawValue.string(value)&.strip.presence
    end

    def self.description(item)
      PlainText.call(RawValue.string(RawValue.object(item&.fetch("basic_info", nil))["short_description"])).presence
    end

    def self.publishers(item)
      list = RawValue.object(item["basic_info"])["publishers"]
      return [] unless list.is_a?(Array)

      list.filter_map { |publisher| text(publisher["name"]) if publisher.is_a?(Hash) }
    end

    def self.developers(item)
      names(item, "developers")
    end

    def self.franchises(item)
      names(item, "franchises")
    end

    def self.names(item, key)
      list = RawValue.object(RawValue.object(item)["basic_info"])[key]
      return [] unless list.is_a?(Array)

      list.filter_map { |entry| unescaped_text(entry["name"]) if entry.is_a?(Hash) }.uniq
    end

    def self.unescaped_text(value)
      RawValue.string(value)&.then { |string| text(CGI.unescapeHTML(string)) }
    end

    def self.earliest_release_on(item)
      release = RawValue.object(item["release"])
      timestamps = RELEASE_DATES.filter_map { |key| RawValue.integer(release[key], min: 1, max: RawValue::TIMESTAMP_MAX) }
      timestamps.min&.then { |timestamp| Time.at(timestamp).utc.to_date }
    end

    def self.tag_ids_by_weight(item)
      tags = item["tags"]
      return [] unless tags.is_a?(Array)

      tags.filter_map { |tag| tag_weight(tag) }
        .sort_by { |tagid, weight| [ -weight, tagid ] }
        .map(&:first)
    end

    def self.tag_weight(tag)
      return unless tag.is_a?(Hash)

      tagid = RawValue.integer(tag["tagid"], min: 1, max: RawValue::INT4_MAX)
      weight = tag["weight"].nil? ? 0 : RawValue.integer(tag["weight"], min: 0, max: RawValue::INT4_MAX)
      [ tagid, weight ] if tagid && weight
    end

    private_class_method :unavailable, :exclusion, :text, :description, :publishers, :names, :unescaped_text,
      :earliest_release_on, :tag_ids_by_weight, :tag_weight
  end
end
