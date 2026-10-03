# The words of a player's public profile (CAP-8, story 4.4).
module PublicProfilesHelper
  # The profile's title: the owner's Steam persona name (user content,
  # escaped wherever it is written), or "Brother <code>" for an owner Steam
  # never named, the code drawn from their token.
  def public_profile_title(player)
    if player.persona_name.present?
      t("public_profiles.title", name: player.persona_name)
    else
      t("public_profiles.fallback_title", code: Accounts::PublicProfile.code(player.token))
    end
  end
end
