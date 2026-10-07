module Accounts
  # Published when a player deletes their account (AD-10, AD-14), inside
  # Accounts::DeletePlayer's transaction, which anonymises the record right
  # after: Game releases what the player holds. Carries the player id only:
  # data = { player_id: }.
  class PlayerDeleted < RubyEventStore::Event
  end
end
