# The words of a player's public profile (CAP-8, story 4.4) and of a card
# shared from it (CAP-9, story 4.5).
module PublicProfilesHelper
  # Open Graph's name of each locale of the URL.
  OG_LOCALES = { "en" => "en_US", "fr" => "fr_FR" }.freeze

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

  # A shared card's title, in the page's and its previews' language: "Portal
  # — Amethyst".
  def shared_card_title(view)
    t("public_profiles.card.og_title", title: view.title, rarity: CardStrings.for([ view ]).rarity_name(view.rarity))
  end

  # The page's locale as Open Graph names it: "en_US", "fr_FR".
  def og_locale
    OG_LOCALES.fetch(I18n.locale.to_s)
  end
end
