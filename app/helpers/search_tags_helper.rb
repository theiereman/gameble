module SearchTagsHelper
  def language_alternates(route)
    I18n.available_locales.to_h { |locale| [ locale.to_s, public_url_for(public_send(route, locale:)) ] }
  end

  def default_language_url
    public_url_for("/")
  end

  def landing_structured_data
    url = language_alternates(:home_path).fetch(I18n.locale.to_s)
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
end
