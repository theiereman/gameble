module SeasonAllocationsHelper
  def allocation_achievement_name(achievement)
    t("achievements.names.#{achievement.key}")
  end
end
