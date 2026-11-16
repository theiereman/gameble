module ExternalLinksHelper
  DONATION_URL = "https://buymeacoffee.com/theiereman".freeze
  SOURCE_CODE_URL = "https://github.com/theiereman/gameble".freeze
  COMMUNITY_URL = "https://discord.gg/B5utMfwEN".freeze
  NEW_TAB = { rel: "noopener noreferrer external", target: "_blank" }.freeze

  def external_link_to(name, url, button: false, hint: nil, **options)
    content = safe_join([
      tag.span(name, class: ("button__label" if button)),
      new_tab_hint(hint),
      (pixel_icon("external", class: "button__icon") if button)
    ].compact)
    link_to content, url, **NEW_TAB, **options
  end

  def donation_link_to(name, **options)
    external_link_to(name, DONATION_URL, button: true, **with_open_beacon("support", options))
  end

  def donation_menu_item_to(name, **options)
    external_menu_item_to(name, DONATION_URL, **with_open_beacon("support", options))
  end

  def source_code_menu_item_to(name, **options)
    external_menu_item_to(name, SOURCE_CODE_URL, **with_open_beacon("source_code", options))
  end

  def source_code_link_to(name, **options)
    external_link_to(name, SOURCE_CODE_URL, button: true, **with_open_beacon("source_code", options))
  end

  def community_menu_item_to(name, **options)
    external_menu_item_to(name, COMMUNITY_URL, **options)
  end

  private

  def with_open_beacon(link, options)
    return options unless current_player

    data = options.fetch(:data, {})
    options.merge(data: data.merge(controller: [ data[:controller], "link-open" ].compact.join(" "),
      action: [ data[:action], "click->link-open#record auxclick->link-open#record" ].compact.join(" "), link_open_url_value: link_open_path(link:)))
  end

  def external_menu_item_to(name, url, number: nil, **options)
    content = safe_join([
      (tag.span(number, class: "menu-item__number", aria: { hidden: true }) if number),
      tag.span(name, class: "menu-item__label"),
      new_tab_hint,
      pixel_icon("external", class: "menu-item__external")
    ].compact)
    link_to content, url, **NEW_TAB, **options
  end

  def new_tab_hint(hint = nil)
    tag.span(" #{hint || t("external_links.new_tab")}", class: "visually-hidden")
  end
end
