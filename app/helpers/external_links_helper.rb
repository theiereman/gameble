module ExternalLinksHelper
  DONATION_URL = "https://buymeacoffee.com/theiereman".freeze

  def external_link_to(name, url, button: false, **options)
    content = safe_join([
      tag.span(name, class: ("button__label" if button)),
      tag.span(" #{t("external_links.new_tab")}", class: "visually-hidden"),
      (pixel_icon("external", class: "button__icon") if button)
    ].compact)
    link_to content, url, rel: "noopener noreferrer external", target: "_blank", **options
  end

  def donation_link_to(name, **options)
    external_link_to(name, DONATION_URL, button: true, **options)
  end
end
