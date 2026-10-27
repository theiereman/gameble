module Accounts
  # Published when a player is created on their first sign-in (AD-10).
  # Carries the player id only: data = { player_id: }.
  class PlayerRegistered < RubyEventStore::Event
  end
end
