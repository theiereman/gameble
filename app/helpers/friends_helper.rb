# The Friends screen and a friend's profile (EXPERIENCE.md, Amis, Friend
# profile).
module FriendsHelper
  # The name a friend goes by on these screens, or the copy deck's nameless
  # officer.
  def friend_name(player)
    player.persona_name.presence || t("friends.show.nameless")
  end

  # The id of the Turbo frame holding a friend's profile, the same in the
  # friend's dialog and in the profile's response, so the response fills it.
  def friend_profile_frame_id(token) = "friend-profile-#{token}"

  # The id of a friend's profile dialog on the Friends screen.
  def friend_dialog_id(token) = "friend-#{token}"
end
