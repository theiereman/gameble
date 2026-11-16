module SeasonTitle
  def self.call(name) = name.presence || I18n.t("booster.title")
end
