module PublicProfilesHelper
  def supporter_badge(player)
    supporter_badge_tag if Game::SupporterStatus.call(player)
  end

  def supporter_badge_tag(compact: false)
    badge, tooltip = t("public_profiles.supporter_badge"), t("public_profiles.supporter_tooltip")
    tag.span(class: [ "supporter-badge", ("supporter-badge--compact" if compact) ], tabindex: (0 unless compact), role: "note", aria: { label: "#{badge}, #{tooltip}" }, data: { tooltip: }) do
      tag.span(badge, class: "supporter-badge__label")
    end
  end

  def public_profile_title(player)
    name = Accounts::PersonaName.clean(player.persona_name)
    if name
      t("public_profiles.title", name:)
    else
      t("public_profiles.fallback_title", code: Accounts::PublicProfile.code(player.token))
    end
  end
end
