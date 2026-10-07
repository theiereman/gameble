namespace :game do
  desc "Runs Game::HealBanksJob now: ten packs for players who never had one, short banks topped up to ten, all packs available at once; idempotent"
  task top_up_banks: :environment do
    abort "game:top_up_banks heals development data only" if Rails.env.production?

    # The job's walker: one transaction per player, a failing player reported
    # and skipped.
    Game::HealBanksJob.perform_now
  end

  # Meant for production: run once after the deploy that creates
  # game_player_states (AD-28).
  desc "Runs Game::BackfillPlayerStatesJob now: a game_player_states row for every player without one, banned included; idempotent"
  task backfill_player_states: :environment do
    # One transaction per player, a failing player reported and skipped:
    # the operator is told how many are left, and the task fails if any.
    Game::BackfillPlayerStatesJob.perform_now
    missing = Game::BackfillPlayerStatesJob.players_without_a_row
    if missing.positive?
      abort "game:backfill_player_states: #{missing} player(s) still without a game_player_states row " \
        "(failures reported to the error tracker); fix them and rerun"
    end

    puts "game:backfill_player_states: every player has their game_player_states row"
  end

  # Meant for production: run once after the deploy that creates
  # game_friend_codes (AD-8).
  desc "Runs Game::BackfillFriendCodesJob now: a friend code for every player without one, banned included; idempotent"
  task backfill_friend_codes: :environment do
    Game::BackfillFriendCodesJob.perform_now
    missing = Game::BackfillFriendCodesJob.players_without_a_code
    abort "game:backfill_friend_codes: #{missing} player(s) still without a friend code; fix them and rerun" if missing.positive?

    puts "game:backfill_friend_codes: every player has their friend code"
  end

  # Meant for production: run once after the deploy that cuts removed
  # players off (story 5.11), and after a ban set from the console until
  # moderation bans through Accounts::PlayerBanned (story 7.5).
  desc "Runs Game::DropFriendsAndTradesJob now: deleted or banned players' open trades cancelled, their friendships and invitations dropped; idempotent"
  task drop_friends_and_trades: :environment do
    Game::DropFriendsAndTradesJob.perform_now
    left = Game::DropFriendsAndTradesJob.players_with_ties.count
    if left.positive?
      abort "game:drop_friends_and_trades: #{left} deleted or banned player(s) still have friends, invitations or open trades " \
        "(failures reported to the error tracker); fix them and rerun"
    end

    puts "game:drop_friends_and_trades: no deleted or banned player has friends, invitations or open trades left"
  end
end
