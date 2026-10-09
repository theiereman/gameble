ActiveRecord::Base.while_preventing_writes do
  conn = ActiveRecord::Base.connection
  q = ->(sql) { conn.select_rows(sql) }
  pct = ->(n, d) { d.zero? ? "0" : format("%.2f%%", 100.0 * n / d) }
  ints = ->(v) { v.is_a?(Array) ? v.map(&:to_i) : v.to_s.delete("{}").split(",").map(&:to_i) }

  version = conn.column_exists?(:catalog_card_seasons, :prestige_score_version) ? "cs.prestige_score_version" : "null"
  season_id = q.("select id from catalog_seasons where status = 'published' order by number desc limit 1").first&.first
  rows = q.(<<~SQL)
    select a.appid, a.name_en, a.tag_ids, a.review_count, a.review_percent_positive,
           cs.rarity, cs.prestige_score, #{version}, cs.rating
    from catalog_card_seasons cs
    join catalog_cards c on c.id = cs.card_id
    join steam_apps a on 'steam:' || a.appid = c.source_key
    where cs.season_id = #{season_id.to_i}
  SQL
  games = rows.map do |appid, name, tags, count, positive, rarity, score, version, rating|
    { appid: appid.to_i, name: name.to_s, top5: ints.(tags).first(5), count: count.to_i, positive: positive.to_i,
      rarity: rarity.to_i, score: score.to_f, version: version, rating: rating }
  end
  n = games.size
  puts "== UNIVERSE: #{n} cards"

  tag_names = q.("select tagid, name from steam_tags").to_h { |id, nm| [ id.to_i, nm ] }
  ids = tag_names.invert
  themes = {
    "Souls-like" => [ "Souls-like" ], "Metroidvania" => [ "Metroidvania" ],
    "Roguelike" => [ "Roguelike", "Roguelite", "Action Roguelike", "Traditional Roguelike" ],
    "Deckbuilder" => [ "Deckbuilding", "Roguelike Deckbuilder", "Card Battler", "Card Game", "Trading Card Game" ],
    "Cosy" => [ "Cozy", "Wholesome", "Relaxing", "Life Sim" ], "Farming" => [ "Farming Sim", "Farming", "Agriculture" ],
    "Horror" => [ "Horror", "Survival Horror", "Psychological Horror", "Lovecraftian" ], "Zombies" => [ "Zombies" ], "Pirates" => [ "Pirates" ],
    "Space" => [ "Space", "Space Sim", "Spaceships" ], "Cyberpunk" => [ "Cyberpunk" ],
    "FPS" => [ "FPS", "Boomer Shooter", "Arena Shooter", "Hero Shooter" ], "Third-person shooter" => [ "Third-Person Shooter" ],
    "Platformer" => [ "Platformer", "2D Platformer", "3D Platformer", "Precision Platformer", "Puzzle Platformer" ],
    "Puzzle" => [ "Puzzle", "Logic" ], "Racing" => [ "Racing", "Driving", "Automobile Sim" ],
    "Sports" => [ "Sports", "Football (Soccer)", "Football (American)", "Basketball", "Golf", "Skateboarding" ],
    "Strategy" => [ "Strategy", "RTS", "Turn-Based Strategy", "Grand Strategy", "4X", "Wargame" ],
    "RPG" => [ "RPG", "JRPG", "CRPG", "Action RPG", "Party-Based RPG", "Tactical RPG", "Strategy RPG" ],
    "Survival" => [ "Survival", "Open World Survival Craft" ], "City builder" => [ "City Builder", "Colony Sim", "Base Building" ],
    "Visual novel" => [ "Visual Novel", "Interactive Fiction", "Dating Sim", "Choose Your Own Adventure" ],
    "Point & click" => [ "Point & Click", "Hidden Object" ], "Fighting" => [ "Fighting", "2D Fighter", "3D Fighter", "Beat 'em up", "Martial Arts" ],
    "Stealth" => [ "Stealth" ], "Rhythm" => [ "Rhythm", "Music" ], "Shoot 'em up" => [ "Shoot 'Em Up", "Bullet Hell", "Twin Stick Shooter", "Bullet Heaven" ],
    "Hack and slash" => [ "Hack and Slash", "Character Action Game", "Spectacle fighter" ], "Post-apocalyptic" => [ "Post-apocalyptic" ],
    "War" => [ "World War II", "World War I", "Military", "War" ], "Medieval" => [ "Medieval" ], "Anime" => [ "Anime" ],
    "Sandbox" => [ "Sandbox" ], "Tower defense" => [ "Tower Defense" ], "Mystery" => [ "Detective", "Mystery", "Investigation" ],
    "Simulation" => [ "Simulation", "Management", "Economy", "Job Simulator", "Hobby Sim", "Time Management", "Cooking", "Shop Keeper" ],
    "Comedy" => [ "Comedy", "Funny", "Memes", "Parody" ], "Open world" => [ "Open World" ], "Idle" => [ "Incremental", "Idler", "Clicker" ],
    "Walking simulator" => [ "Walking Simulator" ], "VR" => [ "VR" ], "Adult" => [ "Sexual Content", "Nudity", "Hentai" ]
  }
  puts "names not found: #{themes.values.flatten.reject { ids[_1] }.inspect}"
  theme_ids = themes.transform_values { |list| list.filter_map { ids[_1] } }
  ufo_count = ->(groups) { games.count { |g| groups.values.none? { (g[:top5] & _1).any? } } }
  full = ufo_count.(theme_ids)
  puts "\n== FINAL LIST (#{themes.size} themes): UFOs #{full} (#{pct.(full, n)})"
  puts "UFOs if one theme is removed: " + theme_ids.keys.map { |t| [ t, ufo_count.(theme_ids.except(t)) ] }
    .sort_by { _2 }.map { "-#{_1} #{pct.(_2, n)}" }.join(" | ")
  [ %w[VR], %w[VR Walking\ simulator], %w[VR Walking\ simulator Idle], %w[Pirates] ].each do |drop|
    puts "without #{drop.join(', ')}: #{pct.(ufo_count.(theme_ids.except(*drop)), n)}"
  end
  sizes = theme_ids.transform_values { |list| games.count { (_1[:top5] & list).any? } }
  puts "sizes: " + sizes.sort_by { -_2 }.map { "#{_1} #{_2}" }.join(" | ")

  puts "\n== RARITY CHECK"
  puts "rarity x prestige_score_version: " + games.group_by { [ _1[:rarity], _1[:version] ] }.sort_by { |k, _| k.map(&:to_i) }.map { |k, gs| "#{k.inspect}:#{gs.size}" }.join(" ")
  games.group_by { _1[:rarity] }.sort.each do |rarity, gs|
    scores = gs.map { _1[:score] }.sort
    counts = gs.map { _1[:count] }.sort
    puts "rarity #{rarity}: score #{scores.first.round(3)}..#{scores.last.round(3)}, review_count median #{counts[counts.size / 2]}, max #{counts.last}"
  end
  puts "most-reviewed Communes: " + games.select { _1[:rarity] == 1 }.max_by(15) { _1[:count] }
    .map { "#{_1[:name]} #{_1[:count]}/#{_1[:positive]}% score=#{_1[:score].round(3)} v=#{_1[:version].inspect} rating=#{_1[:rating]}" }.join(" ; ")
  puts "least-reviewed Légendaires: " + games.select { _1[:rarity] == 5 }.min_by(10) { _1[:count] }
    .map { "#{_1[:name]} #{_1[:count]}/#{_1[:positive]}% score=#{_1[:score].round(3)}" }.join(" ; ")
  formula = ->(g) { Math.log10([ g[:count], 1 ].max) }
  off = games.count { |g| g[:count] >= 200_000 && g[:score] < formula.(g) }
  puts "games with >= 200k reviews whose stored score is below log10(review_count) alone: #{off}"
  puts "season card-seasons with a review count changed since publication can't be told apart here; steam_apps holds the latest import's counts"
  puts "import runs: " + q.("select id, status, started_at::date, finished_at::date from steam_import_runs order by id").map { _1.join(' ') }.join(" | ")
  puts "seasons: " + q.("select number, status, published_at::date from catalog_seasons order by number").map { _1.join(' ') }.join(" | ")
end
