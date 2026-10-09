require "cgi"

ActiveRecord::Base.while_preventing_writes do
  conn = ActiveRecord::Base.connection
  q = ->(sql) { conn.select_rows(sql) }
  pct = ->(n, d) { d.zero? ? "0" : format("%.1f%%", 100.0 * n / d) }
  clean = ->(list) { Array(list).filter_map { |h| h.is_a?(Hash) && h["name"].is_a?(String) ? CGI.unescapeHTML(h["name"]).strip.presence : nil }.uniq }

  season = q.("select id, number from catalog_seasons where status = 'published' order by number desc limit 1").first
  rows =
    if season
      q.(<<~SQL)
        select a.appid, a.name_en, a.tag_ids, a.review_count, a.review_percent_positive,
               a.details->'basic_info'->'developers', a.details->'basic_info'->'franchises', a.publishers
        from catalog_card_seasons cs
        join catalog_cards c on c.id = cs.card_id
        join steam_apps a on 'steam:' || a.appid = c.source_key
        where cs.season_id = #{season[0]}
      SQL
    else
      []
    end
  universe = "season #{season&.last} (#{rows.size} cards matched to steam_apps)"
  if rows.empty?
    rows = q.(<<~SQL)
      select appid, name_en, tag_ids, review_count, review_percent_positive,
             details->'basic_info'->'developers', details->'basic_info'->'franchises', publishers
      from steam_apps where details is not null and details_exclusion is null and review_exclusion is null and review_count is not null
    SQL
    universe = "FALLBACK kept steam_apps (#{rows.size})"
  end

  tag_names = q.("select tagid, name from steam_tags").to_h { |id, n| [ id.to_i, n ] }
  parse_ints = ->(v) { v.is_a?(Array) ? v.map(&:to_i) : v.to_s.delete("{}").split(",").map(&:to_i) }
  parse_strs = ->(v) { v.is_a?(Array) ? v : v.to_s.delete("{}").split(",").map { _1.delete('"') } }
  games = rows.map do |appid, name, tags, count, positive, devs, frs, pubs|
    { appid: appid.to_i, name: name, top5: parse_ints.(tags).first(5), count: count.to_i, positive: positive.to_i,
      devs_raw: devs, frs_raw: frs,
      devs: clean.(devs.is_a?(String) ? JSON.parse(devs) : devs),
      frs: clean.(frs.is_a?(String) ? JSON.parse(frs) : frs),
      pubs: parse_strs.(pubs).map { CGI.unescapeHTML(_1).strip } }
  end
  n = games.size
  puts "== UNIVERSE: #{universe}"

  puts "\n== RAW FIELDS"
  puts "developers key present: #{games.count { _1[:devs_raw] }}, non-empty: #{games.count { _1[:devs].any? }} (#{pct.(games.count { _1[:devs].any? }, n)})"
  puts "franchises key present: #{games.count { _1[:frs_raw] }}, non-empty: #{games.count { _1[:frs].any? }} (#{pct.(games.count { _1[:frs].any? }, n)})"
  puts "games with >1 developer: #{games.count { _1[:devs].size > 1 }}, >1 franchise: #{games.count { _1[:frs].size > 1 }}"
  puts "names holding an HTML entity before unescape: devs #{games.count { _1[:devs_raw].to_s.include?('&amp;') }}, franchises #{games.count { _1[:frs_raw].to_s.include?('&amp;') }}"

  group_report = lambda do |label, key, mins, top|
    by = Hash.new { |h, k| h[k] = [] }
    games.each { |g| g[key].each { by[_1] << g } }
    puts "\n== #{label.upcase}: #{by.size} distinct"
    mins.each do |m|
      sets = by.select { |_, gs| gs.size >= m }
      covered = sets.values.flatten.map { _1[:appid] }.uniq.size
      puts "min #{m}: #{sets.size} sets, #{covered} cards covered (#{pct.(covered, n)}), median size #{sets.values.map(&:size).sort[sets.size / 2]}"
    end
    puts "top #{top}: " + by.sort_by { |k, gs| [ -gs.size, k ] }.first(top).map { |k, gs| "#{k} (#{gs.size})" }.join(" | ")
    by
  end
  franchises = group_report.("franchises", :frs, [ 2, 3, 4, 5 ], 60)
  pub_like = franchises.select { |name, gs| gs.size >= 2 && gs.all? { |g| (g[:pubs] + g[:devs]).any? { _1.casecmp?(name) } } }
  puts "franchises (>=2) named like every game's publisher or developer: #{pub_like.size}: " + pub_like.sort_by { -_2.size }.first(30).map { "#{_1} (#{_2.size})" }.join(" | ")
  sample = franchises.select { |_, gs| gs.size.between?(3, 4) }.to_a.sample(8, random: Random.new(1))
  sample.each { |k, gs| puts "  sample #{k}: #{gs.map { _1[:name] }.first(4).join(' / ')}" }
  group_report.("studios (every developer)", :devs, [ 2, 3, 4, 5, 6, 8 ], 50)

  top5_count = Hash.new(0)
  games.each { |g| g[:top5].each { top5_count[_1] += 1 } }
  puts "\n== TAGS IN TOP 5 (top 160): " + top5_count.sort_by { -_2 }.first(160).map { "#{tag_names[_1] || _1} #{_2}" }.join(" | ")

  themes = {
    "Souls-like" => [ "Souls-like" ], "Metroidvania" => [ "Metroidvania" ],
    "Roguelike" => [ "Roguelike", "Roguelite", "Action Roguelike", "Traditional Roguelike" ],
    "Deckbuilder" => [ "Deckbuilding", "Roguelike Deckbuilder", "Card Battler", "Card Game", "Trading Card Game" ],
    "Cosy" => [ "Cozy", "Wholesome" ], "Horror" => [ "Horror", "Survival Horror", "Psychological Horror" ],
    "Zombies" => [ "Zombies" ], "Pirates" => [ "Pirates" ], "Space" => [ "Space", "Space Sim", "Spaceships" ],
    "Cyberpunk" => [ "Cyberpunk" ], "FPS" => [ "FPS", "Boomer Shooter", "Arena Shooter", "Hero Shooter" ],
    "Platformer" => [ "Platformer", "2D Platformer", "3D Platformer", "Precision Platformer", "Puzzle Platformer" ],
    "Puzzle" => [ "Puzzle", "Logic" ], "Racing" => [ "Racing", "Driving" ],
    "Sports" => [ "Sports", "Football (Soccer)", "Football (American)", "Basketball", "Golf", "Skateboarding" ],
    "Strategy" => [ "Strategy", "RTS", "Turn-Based Strategy", "Grand Strategy", "4X", "Wargame" ],
    "RPG" => [ "RPG", "JRPG", "CRPG", "Action RPG", "Party-Based RPG", "Tactical RPG", "Strategy RPG" ],
    "Survival" => [ "Survival", "Open World Survival Craft" ], "City builder" => [ "City Builder", "Colony Sim", "Base Building" ],
    "Visual novel" => [ "Visual Novel", "Interactive Fiction", "Dating Sim" ], "Point & click" => [ "Point & Click", "Hidden Object" ],
    "Fighting" => [ "Fighting", "2D Fighter", "3D Fighter", "Beat 'em up", "Martial Arts" ], "Stealth" => [ "Stealth" ],
    "Rhythm" => [ "Rhythm" ], "Shoot 'em up" => [ "Shoot 'Em Up", "Bullet Hell", "Twin Stick Shooter", "Bullet Heaven" ],
    "Hack and slash" => [ "Hack and Slash", "Character Action Game", "Spectacle fighter" ],
    "Post-apocalyptic" => [ "Post-apocalyptic" ], "War" => [ "World War II", "World War I", "Military", "War" ],
    "Medieval" => [ "Medieval" ], "Anime" => [ "Anime" ], "Sandbox" => [ "Sandbox" ], "Farming" => [ "Farming Sim", "Farming", "Agriculture" ],
    "Tower defense" => [ "Tower Defense" ], "Mystery" => [ "Detective", "Mystery", "Investigation" ], "Lovecraftian" => [ "Lovecraftian" ]
  }
  ids_by_name = tag_names.invert
  missing = themes.values.flatten.reject { ids_by_name[_1] }
  puts "\n== THEMES (draft, #{themes.size}); tag names not found: #{missing.inspect}"
  theme_ids = themes.transform_values { |names| names.filter_map { ids_by_name[_1] } }
  members = ->(ids) { games.select { |g| (g[:top5] & ids).any? } }
  themes.each_key { |t| puts "#{t}: #{members.(theme_ids[t]).size}" }
  listed = theme_ids.values.flatten
  ufos = games.reject { |g| (g[:top5] & listed).any? }
  puts "UFOs: #{ufos.size} (#{pct.(ufos.size, n)})"
  per_card = games.map { |g| theme_ids.count { |_, ids| (g[:top5] & ids).any? } }.tally.sort
  puts "themes per card: #{per_card.map { "#{_1}:#{_2}" }.join(' ')}"
  main = Hash.new(0)
  games.each do |g|
    first = g[:top5].find { listed.include?(_1) }
    main[first ? theme_ids.find { |_, ids| ids.include?(first) }.first : "(UFO)"] += 1
  end
  puts "main theme: " + main.sort_by { -_2 }.map { "#{_1} #{_2}" }.join(" | ")
  ufo_tags = Hash.new(0)
  ufos.each { |g| g[:top5].each { ufo_tags[_1] += 1 } }
  puts "tags in UFOs' top 5 (top 50): " + ufo_tags.sort_by { -_2 }.first(50).map { "#{tag_names[_1] || _1} #{_2}" }.join(" | ")
  puts "UFO sample: " + ufos.sample(25, random: Random.new(2)).map { "#{_1[:name]} [#{_1[:top5].map { |t| tag_names[t] }.join(', ')}]" }.join(" ; ")
  broad = [ "Action", "Adventure", "Casual", "Indie", "Singleplayer", "Multiplayer", "Co-op", "Online Co-Op", "Local Co-Op",
    "Local Multiplayer", "PvP", "PvE", "Early Access", "Free to Play", "2D", "3D", "First-Person", "Third Person", "Pixel Graphics",
    "Great Soundtrack", "Atmospheric", "Story Rich", "Colorful", "Cute", "Funny", "Comedy", "Difficult", "Classic",
    "Family Friendly", "Exploration", "Realistic", "Stylized", "Cartoony", "Retro", "Beautiful", "Immersive", "Simulation",
    "Shooter", "Open World", "Fantasy", "Sci-fi", "Massively Multiplayer", "Arcade", "Casual" ].filter_map { ids_by_name[_1] }
  remaining = ufos
  greedy = []
  12.times do
    gains = Hash.new(0)
    remaining.each { |g| (g[:top5] - broad).each { gains[_1] += 1 } }
    best = gains.max_by { _2 } or break
    remaining = remaining.reject { _1[:top5].include?(best[0]) }
    greedy << "#{tag_names[best[0]]} +#{best[1]} -> #{pct.(remaining.size, n)}"
  end
  puts "greedy non-broad additions: " + greedy.join(" | ")
  broad_ufos = ufos.reject { |g| (g[:top5] - broad).any? }
  puts "UFOs whose top 5 holds only broad tags: #{broad_ufos.size}"

  puts "\n== REVIEWS"
  counts = games.map { _1[:count] }.sort
  pctl = ->(p) { counts[[ (p * (n - 1)).round, n - 1 ].min] }
  puts "review_count percentiles: " + [ 0, 0.1, 0.25, 0.5, 0.75, 0.9, 0.95, 0.98, 0.99, 0.995, 0.999, 1 ].map { "p#{(_1 * 100).round(1)}=#{pctl.(_1)}" }.join(" ")
  puts "percent positive buckets: " + games.map { [ _1[:positive] / 5 * 5, 95 ].min }.tally.sort.map { "#{_1}+:#{_2}" }.join(" ")
  puts "Steam labels: Overwhelmingly/Very positive(>=80): #{games.count { _1[:positive] >= 80 }}, Mixed(40-69): #{games.count { _1[:positive].between?(40, 69) }}, Negative(<40): #{games.count { _1[:positive] < 40 }}"
  [ 95, 96, 97, 98 ].each do |p|
    puts "Intouchables pos>=#{p}: " + [ 5_000, 10_000, 20_000, 50_000, 100_000 ].map { |c| "count>=#{c}:#{games.count { _1[:positive] >= p && _1[:count] >= c }}" }.join(" ")
    puts "Pepites     pos>=#{p}: " + [ 600, 750, 1_000, 1_500, 2_000 ].map { |c| "count<#{c}:#{games.count { _1[:positive] >= p && _1[:count] < c }}" }.join(" ")
  end
  [ [ 40, 69 ], [ 50, 69 ], [ 40, 74 ] ].each do |lo, hi|
    puts "Mal-aimes pos #{lo}-#{hi}: " + [ 5_000, 10_000, 20_000, 50_000 ].map { |c| "count>=#{c}:#{games.count { _1[:positive].between?(lo, hi) && _1[:count] >= c }}" }.join(" ")
  end
  puts "Phenomenes: " + [ 50_000, 100_000, 200_000, 300_000, 500_000 ].map { |c| "count>=#{c}:#{games.count { _1[:count] >= c }}" }.join(" ")
  puts "top 15 reviewed: " + games.max_by(15) { _1[:count] }.map { "#{_1[:name]} #{_1[:count]}/#{_1[:positive]}%" }.join(" | ")
end
