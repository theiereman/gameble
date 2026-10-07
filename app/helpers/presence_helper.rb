# A friend's presence in words (EXPERIENCE.md, Copy deck, Presence; DESIGN.md,
# Friend row), from a Game::FriendsPresence::Row: "En ligne", the activity
# ("Ouvre un booster"), or the time since they were last seen, compact
# ("Il y a 3 h"); "Hors ligne" when never seen. An activity key without
# words reads as online.
module PresenceHelper
  def presence_text(row, now: Time.current)
    case row.state
    when :active then t("friends.show.presence.activities.#{row.activity}", default: t("friends.show.presence.online"))
    when :online then t("friends.show.presence.online")
    else row.seen_at ? presence_ago(now - row.seen_at) : t("friends.show.presence.offline")
    end
  end

  private
    def presence_ago(seconds)
      minutes = [ (seconds / 60).floor, 1 ].max
      if minutes < 60
        t("friends.show.presence.minutes_ago", count: minutes)
      elsif minutes < 24 * 60
        t("friends.show.presence.hours_ago", count: minutes / 60)
      else
        t("friends.show.presence.days_ago", count: minutes / (24 * 60))
      end
    end
end
