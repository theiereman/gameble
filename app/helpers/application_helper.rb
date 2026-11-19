module ApplicationHelper
  def season_title(season) = SeasonTitle.call(season&.name(I18n.locale))

  # One read per request, shared by the controller's gate and every view.
  def feature_enabled?(key) = (request.env["gameble.enabled_features"] ||= Game::EnabledFeatures.call).include?(key.to_s)
end
