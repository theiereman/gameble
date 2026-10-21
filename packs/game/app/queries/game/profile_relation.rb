module Game
  module ProfileRelation
    def self.call(viewer, owner)
      return :visitor if viewer.nil?
      return :self if viewer.id == owner.id
      return :friends if FriendshipBetween.call(viewer, owner)

      sent = Invitation.unanswered
        .where(sender_id: [ viewer.id, owner.id ], recipient_id: [ viewer.id, owner.id ]).pluck(:sender_id, :status)
      if sent.include?([ owner.id, "pending" ]) then :invited_by
      elsif sent.any? { |sender_id, _| sender_id == viewer.id } then :invited
      else :none
      end
    end
  end
end
