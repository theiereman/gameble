module ProfileTitlesHelper
  def profile_title_text(title)
    t("profile_titles.title", rank: t("profile_titles.ranks.#{title.rank}"), set: SetLabel.for(title))
  end

  def profile_title_options(titles, active, none_label)
    ranked = titles.group_by(&:rank).map do |rank, group|
      options = group.map { |title| tag.option(profile_title_text(title), value: "#{title.rank}:#{title.kind}:#{title.key}", selected: title == active) }
      tag.optgroup(safe_join(options), label: t("profile_titles.ranks.#{rank}"))
    end
    safe_join([ tag.option(none_label, value: "", selected: active.nil?), *ranked ])
  end

  def active_title_tag(title, class_name: nil)
    tag.span(profile_title_text(title), class: class_names("profile-title", class_name)) if title
  end
end
