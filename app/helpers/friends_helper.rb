module FriendsHelper
  def friend_name(player)
    Accounts::PersonaName.clean(player&.persona_name) || t("friends.show.nameless")
  end

  def invited_name(player, code)
    Accounts::PersonaName.clean(player&.persona_name) || code || t("friends.show.nameless")
  end

  def friend_profile_frame_id(token) = "friend-profile-#{token}"

  def friend_dialog_id(token) = "friend-#{token}"

  def remove_friend_dialog_id(token) = "remove-friend-#{token}"

  def friend_actions_menu_id(token) = "friend-actions-#{token}"

  def friend_profile_actions_menu_id(token) = "friend-profile-actions-#{token}"

  def friend_profile_remove_dialog_id(token) = "friend-profile-remove-#{token}"

  def friend_report_dialog_id(token) = "report-dialog-#{token}"

  def dialog_opener_attributes(dialog_id, label:)
    { aria: { haspopup: "dialog", label: }, data: { controller: "dialog-opener", action: "dialog-opener#open", dialog_opener_dialog_value: dialog_id } }
  end
end
