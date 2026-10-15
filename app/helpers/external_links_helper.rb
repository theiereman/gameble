module ExternalLinksHelper
  DONATION_URL = "https://buymeacoffee.com/theiereman".freeze
  SOURCE_CODE_URL = "https://github.com/theiereman/gameble".freeze
  NEW_TAB = { rel: "noopener noreferrer external", target: "_blank" }.freeze

  def external_link_to(name, url, button: false, **options)
    content = safe_join([
      tag.span(name, class: ("button__label" if button)),
      new_tab_hint,
      (pixel_icon("external", class: "button__icon") if button)
    ].compact)
    link_to content, url, **NEW_TAB, **options
  end

  def donation_link_to(name, **options)
    external_link_to(name, DONATION_URL, button: true, **options)
  end

  def donation_menu_item_to(name, number: nil, **options)
    content = safe_join([
      (tag.span(number, class: "menu-item__number", aria: { hidden: true }) if number),
      tag.span(name, class: "menu-item__label"),
      new_tab_hint,
      pixel_icon("external", class: "menu-item__external")
    ].compact)
    link_to content, DONATION_URL, **NEW_TAB, **options
  end

  private

  def new_tab_hint
    tag.span(" #{t("external_links.new_tab")}", class: "visually-hidden")
  end
end
