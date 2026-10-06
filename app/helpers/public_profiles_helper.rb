# The words of a player's public profile (CAP-8, story 4.4).
module PublicProfilesHelper
  # The profile's title: the owner's Steam persona name (user content,
  # escaped wherever it is written), or "Player <code>" for an owner Steam
  # never named, the code drawn from their token. The stored name is cleaned
  # again (Accounts::PersonaName), so a name stored before invisible
  # characters were cleaned at sign-in, and that holds nothing visible, falls
  # back too.
  def public_profile_title(player)
    name = Accounts::PersonaName.clean(player.persona_name)
    if name
      t("public_profiles.title", name:)
    else
      t("public_profiles.fallback_title", code: Accounts::PublicProfile.code(player.token))
    end
  end
end
