module PublicProfilesHelper
  def public_profile_title(player)
    name = Accounts::PersonaName.clean(player.persona_name)
    if name
      t("public_profiles.title", name:)
    else
      t("public_profiles.fallback_title", code: Accounts::PublicProfile.code(player.token))
    end
  end
end
