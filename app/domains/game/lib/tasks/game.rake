namespace :game do
  desc "Runs Game::HealBanksJob now: ten packs for players who never had one, short banks topped up to ten, all packs available at once, unopened packs of an earlier season redrawn in the published one; idempotent"
  task top_up_banks: :environment do
    abort "game:top_up_banks heals development data only" if Rails.env.production?

    Game::HealBanksJob.perform_now
  end

  desc "Runs Game::BackfillPlayerStatesJob now: a game_player_states row for every player without one, banned included; idempotent"
  task backfill_player_states: :environment do
    Game::BackfillPlayerStatesJob.perform_now
    missing = Game::BackfillPlayerStatesJob.players_without_a_row
    if missing.positive?
      abort "game:backfill_player_states: #{missing} player(s) still without a game_player_states row " \
        "(failures reported to the error tracker); fix them and rerun"
    end

    puts "game:backfill_player_states: every player has their game_player_states row"
  end

  desc "Runs Game::BackfillFriendCodesJob now: a friend code for every player without one, banned included; idempotent"
  task backfill_friend_codes: :environment do
    Game::BackfillFriendCodesJob.perform_now
    missing = Game::BackfillFriendCodesJob.players_without_a_code
    abort "game:backfill_friend_codes: #{missing} player(s) still without a friend code; fix them and rerun" if missing.positive?

    puts "game:backfill_friend_codes: every player has their friend code"
  end

  desc "Runs Game::BackfillAchievementsJob now: every achievement a player in good standing already met is granted, without a toast; idempotent"
  task backfill_achievements: :environment do
    Game::BackfillAchievementsJob.perform_now

    puts "game:backfill_achievements: done; any failure went to the error tracker, and a rerun grants only what is missing"
  end

  desc "Runs Game::BackfillCardBacksJob now: the back of every set whose back tier a player in good standing already reached is unlocked, without a toast; idempotent"
  task backfill_card_backs: :environment do
    Game::BackfillCardBacksJob.perform_now

    puts "game:backfill_card_backs: done; any failure went to the error tracker, and a rerun unlocks only what is missing"
  end

  desc "Grants an event card back (saison-1, millesime-2017 or soldes-hiver) to the players with these Steam ids, separated by spaces; each player in a transaction of their own, a rerun grants only what is missing"
  task :grant_card_back, %i[back steam_ids] => :environment do |_task, args|
    back = args[:back].to_s
    abort "game:grant_card_back: #{back.inspect} is not an event back (#{Game::CardBacks::EVENT_BACK_KEYS.join(", ")})" unless Game::CardBacks.event?(back)

    steam_ids = args[:steam_ids].to_s.split.uniq
    abort "game:grant_card_back: give the Steam ids of the players, separated by spaces" if steam_ids.empty?

    outcome = Game::GrantCardBackJob.grant(back:, steam_ids:)
    puts "game:grant_card_back: #{back}: #{outcome.granted} granted, #{outcome.already_held} already held, " \
         "#{outcome.not_found} not found or banned, #{outcome.failed} failed (see the error tracker)"
  end

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
