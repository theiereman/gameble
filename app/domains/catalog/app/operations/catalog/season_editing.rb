module Catalog
  module SeasonEditing
    private

    def validate_season_names(name_en:, name_fr:)
      names = { name_en: ThemeNaming.clean(name_en), name_fr: ThemeNaming.clean(name_fr) }
      names.values.all? { ThemeNaming.valid?(it, length: Season::NAME_LENGTH) } ? Success(names) : Failure(:invalid_season_name)
    end

    def lock_published(number)
      season = Season.published.where(number:).lock("FOR UPDATE").take
      season ? Success(season) : Failure(:no_published_season)
    end
  end
end
