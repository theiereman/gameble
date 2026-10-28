module ProfileTitlesHelper
  def profile_title_text(title)
    t("profile_titles.title", rank: t("profile_titles.ranks.#{title.rank}"), set: SetLabel.for(title))
  end
end
