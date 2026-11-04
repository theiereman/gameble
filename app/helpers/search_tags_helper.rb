module SearchTagsHelper
  OG_LOCALES = { "en" => "en_US", "fr" => "fr_FR" }.freeze

  def language_alternates(route)
    I18n.available_locales.to_h { |locale| [ locale.to_s, public_url_for(public_send(route, locale:)) ] }
  end

  def current_language_url(route)
    language_alternates(route).fetch(I18n.locale.to_s)
  end

  def og_locale
    og_locale_for(I18n.locale.to_s)
  end

  def og_locale_for(locale)
    OG_LOCALES.fetch(locale, locale)
  end

  def default_meta_description
    return unless Rails.configuration.x.search_indexing
    return if description_already_set?

    tag.meta name: "description", content: t("layouts.application.description")
  end

  def default_language_url
    public_url_for("/")
  end

  def card_structured_data(view, title:, url:, image:)
    page = { "@type" => "WebPage", "@id" => "#{url}#webpage", "url" => url, "name" => title,
             "description" => t("card_details.preview.description"), "inLanguage" => I18n.locale.to_s,
             "isPartOf" => { "@type" => "WebSite", "name" => t("layouts.application.application_name"),
                             "url" => public_url_for(home_path) },
             "about" => { "@type" => "VideoGame", "name" => view.title } }
    page["primaryImageOfPage"] = { "@type" => "ImageObject", "url" => image[:url], "width" => CardShareImage::WIDTH,
                                   "height" => CardShareImage::HEIGHT, "caption" => image[:alt] } if image
    ERB::Util.json_escape(JSON.generate({ "@context" => "https://schema.org", **page }))
  end

  def landing_structured_data
    url = current_language_url(:home_path)
    graph = [
      { "@type" => "WebSite", "@id" => "#{url}#website", "name" => t("layouts.application.application_name"),
        "url" => url, "inLanguage" => I18n.locale.to_s },
      { "@type" => "VideoGame", "name" => t("layouts.application.application_name"), "url" => url,
        "description" => t("landings.show.description"), "applicationCategory" => "Game",
        "genre" => t("landings.show.structured_data.genre"), "operatingSystem" => "Web browser",
        "playMode" => "MultiPlayer", "isAccessibleForFree" => true,
        "availableLanguage" => I18n.available_locales.map(&:to_s),
        "offers" => { "@type" => "Offer", "price" => "0", "priceCurrency" => "EUR" } }
    ]
    ERB::Util.json_escape(JSON.generate({ "@context" => "https://schema.org", "@graph" => graph }))
  end

  private
    def description_already_set?
      content_for(:head).to_s.include?('name="description"')
    end
end
