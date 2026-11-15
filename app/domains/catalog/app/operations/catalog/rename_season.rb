module Catalog
  class RenameSeason < ApplicationOperation
    include SeasonEditing

    def call(number:, name_en:, name_fr:)
      names = step validate_season_names(name_en:, name_fr:)

      transaction do
        season = step lock_published(number)
        season.update!(names)
        step publish(SeasonRenamed.new(data: { season_id: season.id }), stream_name: Season.stream_name(season.id))
        season
      end
    end
  end
end
