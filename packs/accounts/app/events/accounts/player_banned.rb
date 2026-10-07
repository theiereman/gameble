module Accounts
  # Published when a moderator bans a player (CAP-15, AD-14), inside the ban's
  # transaction: Game cuts the player off from their friends and trades
  # (Game::Handlers::PlayerBanned). The ban action itself comes with
  # moderation (story 7.5); until then a ban is `banned_at` set from the
  # console, followed by `bin/rails game:drop_friends_and_trades`. Carries the
  # player id only: data = { player_id: }.
  class PlayerBanned < RubyEventStore::Event
  end
end
