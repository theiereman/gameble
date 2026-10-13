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
end
