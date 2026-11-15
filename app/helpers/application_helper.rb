module ApplicationHelper
  def season_title(season) = SeasonTitle.call(season&.name(I18n.locale))
end
