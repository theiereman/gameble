module Game
  # Published when a player sends a friend invitation (AD-8, AD-10).
  # Identifiers only: data = { invitation_id:, sender_id:, recipient_id: }, on
  # the sender's stream.
  class InvitationSent < RubyEventStore::Event
  end
end
