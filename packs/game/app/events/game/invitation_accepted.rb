module Game
  # Published when a player accepts a friend invitation, in the transaction
  # that creates the friendship (AD-8, AD-10). Identifiers only:
  # data = { invitation_id:, sender_id:, recipient_id: }, on the accepting
  # player's stream.
  class InvitationAccepted < RubyEventStore::Event
  end
end
