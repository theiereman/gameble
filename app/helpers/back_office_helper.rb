module BackOfficeHelper
  def moderation_name(player)
    player.deleted? ? t("back_office.history.index.deleted_account") : public_profile_title(player)
  end

  def sign_in_providers(player)
    player.identities.map { |identity| t("sign_ins.providers.#{identity.provider}") }.sort.join(", ")
  end
end
