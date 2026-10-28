module ProfileTitlesHelper
  def profile_title_text(title)
    t("profile_titles.title", rank: t("profile_titles.ranks.#{title.rank}"), set: SetLabel.for(title))
  end

  def active_title_tag(title, class_name: nil)
    tag.span(profile_title_text(title), class: class_names("profile-title", class_name)) if title
  end
end
