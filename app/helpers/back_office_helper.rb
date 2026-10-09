module BackOfficeHelper
  def moderation_name(player)
    player.deleted? ? t("back_office.history.index.deleted_account") : public_profile_title(player)
  end
end
