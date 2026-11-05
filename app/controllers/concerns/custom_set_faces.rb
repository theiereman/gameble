module CustomSetFaces
  extend ActiveSupport::Concern

  private
    def custom_set_members(card_ids, editions)
      faces = Catalog::LatestPublishedCardSeasons.call(card_ids)
      card_ids.filter_map { |card_id| [ faces[card_id], card_id ] if faces.key?(card_id) || editions.key?(card_id) }
    end

    def custom_set_shown_ids(members, editions)
      members.map { |card_season_id, card_id| editions[card_id]&.card_season_id || card_season_id }
    end
end
