module Game
  module CustomSetCardIds
    def self.call(custom_set_ids)
      CustomSetGame.where(custom_set_id: custom_set_ids).order(:id).pluck(:custom_set_id, :card_id)
        .group_by(&:first).transform_values { |pairs| pairs.map(&:last) }
    end
  end
end
