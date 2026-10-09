require "cgi"

ActiveRecord::Base.while_preventing_writes do
  conn = ActiveRecord::Base.connection
  q = ->(sql) { conn.select_rows(sql) }
  pct = ->(n, d) { d.zero? ? "0" : format("%.1f%%", 100.0 * n / d) }
  names = ->(json) { Array(json.is_a?(String) ? JSON.parse(json) : json).filter_map { |h| h.is_a?(Hash) && h["name"].is_a?(String) ? CGI.unescapeHTML(h["name"]).strip.presence : nil }.uniq }
  ints = ->(v) { v.is_a?(Array) ? v.map(&:to_i) : v.to_s.delete("{}").split(",").map(&:to_i) }
  strs = ->(v) { v.is_a?(Array) ? v : v.to_s.delete("{}").split(",").map { _1.delete('"') } }

  season_id = q.("select id from catalog_seasons where status = 'published' order by number desc limit 1").first&.first
  rows = q.(<<~SQL)
    select a.appid, a.name_en, a.tag_ids, a.review_count, a.review_percent_positive,
           a.details->'basic_info'->'developers', a.details->'basic_info'->'franchises', a.publishers, cs.rarity
    from catalog_card_seasons cs
    join catalog_cards c on c.id = cs.card_id
    join steam_apps a on 'steam:' || a.appid = c.source_key
    where cs.season_id = #{season_id.to_i}
  SQL
  if rows.empty?
    rows = q.("select appid, name_en, tag_ids, review_count, review_percent_positive, details->'basic_info'->'developers', details->'basic_info'->'franchises', publishers, 1 + (appid % 5) from steam_apps where details is not null and details_exclusion is null and review_exclusion is null and review_count is not null")
    puts "FALLBACK (local validation only)"
  end
  games = rows.map do |appid, name, tags, count, positive, devs, frs, pubs, rarity|
    { appid: appid.to_i, name: name.to_s, top5: ints.(tags).first(5), count: count.to_i, positive: positive.to_i,
      devs: names.(devs), frs: names.(frs), pubs: strs.(pubs).map { CGI.unescapeHTML(_1).strip }, rarity: rarity.to_i }
  end
  n = games.size
  puts "== UNIVERSE: #{n} cards"

  tier_odds = { 1 => 0.76, 2 => 0.19, 3 => 0.043, 4 => 0.0065, 5 => 0.0005 }
  tier_size = games.map { _1[:rarity] }.tally
  puts "rarity sizes: #{tier_size.sort.map { "#{_1}:#{_2}" }.join(' ')}"
  card_p = ->(g) { tier_odds.fetch(g[:rarity], 0.76) / tier_size.fetch(g[:rarity]) }
  rng = Random.new(7)
  packs_to = lambda do |set|
    return "-" if set.empty?
    runs = Array.new(31) { set.map { -Math.log(1 - rng.rand) / (5 * card_p.(_1)) }.sort }
    [ 0.25, 0.5, 1.0 ].map do |f|
      k = [ (f * set.size).ceil, 1 ].max - 1
      runs.map { _1[k] }.sort[15].round
    end.join("/")
  end
  rarity_mix = ->(set) { set.map { _1[:rarity] }.tally.sort.map { "#{_1}:#{_2}" }.join(" ") }

  company_norm = lambda do |s|
    s.downcase.gsub(/[™®©]/, "").gsub(/\((mac|linux|windows|pc|macos)\)/, "")
      .gsub(/[,.]?\s*\b(co\.?,?\s*ltd|ltd|inc|llc|s\.?r\.?l|gmbh|s\.?a|corporation|corp|k\.?k|limited|co)\b\.?/, "")
      .gsub(/[^\p{L}\p{N}]+/, " ").strip
  end
  companies = games.flat_map { _1[:devs] + _1[:pubs] }.map(&company_norm).to_set
  franchise_norm = ->(s) { s.downcase.gsub(/[™®©]/, "").sub(/\s*-\s*official\z/, "").sub(/\s+(franchise|series)\z/, "").gsub(/[^\p{L}\p{N}']+/, " ").strip }
  stop = %w[the of and a an in on game games]
  title_hit = lambda do |franchise, game|
    tokens = franchise_norm.(franchise).split.reject { stop.include?(_1) || _1.size < 3 }
    title = game[:name].downcase.gsub(/[^\p{L}\p{N}']+/, " ")
    tokens.any? { title.include?(_1) }
  end

  by_franchise = Hash.new { |h, k| h[k] = [] }
  games.each { |g| g[:frs].each { by_franchise[_1] << g } }
  multi = by_franchise.select { |_, gs| gs.size >= 2 }
  is_company = ->(f) { companies.include?(company_norm.(f)) }
  titled = ->(f, gs) { gs.count { title_hit.(f, _1) } * 2 > gs.size }
  puts "\n== FRANCHISE FILTERS (franchises with >= 2 games: #{multi.size})"
  filters = {
    "none" => ->(_f, _gs) { true },
    "not a company name" => ->(f, _gs) { !is_company.(f) },
    "majority of titles share a word" => ->(f, gs) { titled.(f, gs) },
    "both" => ->(f, gs) { !is_company.(f) && titled.(f, gs) }
  }
  filters.each do |label, keep|
    kept = multi.select { |f, gs| keep.(f, gs) }
    line = [ 2, 3, 4 ].map do |m|
      sets = kept.select { |_, gs| gs.size >= m }
      "min #{m}: #{sets.size} sets / #{sets.values.flatten.map { _1[:appid] }.uniq.size} cards"
    end
    puts "#{label}: #{line.join(' | ')}"
  end
  dropped = multi.reject { |f, gs| !is_company.(f) && titled.(f, gs) }
  puts "dropped by 'both', >=3 games (#{dropped.count { _2.size >= 3 }}): " + dropped.select { _2.size >= 3 }.sort_by { -_2.size }.map { "#{_1} (#{_2.size}#{is_company.(_1) ? ',co' : ''})" }.join(" | ")
  kept3 = multi.select { |f, gs| gs.size >= 3 && !is_company.(f) && titled.(f, gs) }
  puts "kept by 'both', min 3, top 80: " + kept3.sort_by { -_2.size }.first(80).map { "#{_1} (#{_2.size})" }.join(" | ")
  puts "kept by 'both', min 3, random 25: " + kept3.to_a.sample(25, random: Random.new(3)).map { "#{_1} (#{_2.size})" }.join(" | ")
  puts "packs to complete a kept franchise (25/50/100%), sizes 3,5,10 sampled:"
  [ 3, 5, 10 ].each do |s|
    f, gs = kept3.select { _2.size == s }.to_a.sample(1, random: Random.new(s)).first
    puts "  #{f} (#{s}, rarities #{rarity_mix.(gs)}): #{packs_to.(gs)}" if f
  end

  puts "\n== STUDIOS (normalized: legal suffixes, (Mac)/(Linux), case)"
  [ [ "every developer", ->(g) { g[:devs] } ], [ "first developer", ->(g) { g[:devs].first(1) } ] ].each do |label, pick|
    by = Hash.new { |h, k| h[k] = [] }
    display = {}
    games.each { |g| pick.(g).each { |d| key = company_norm.(d); display[key] ||= d; by[key] << g } }
    puts "#{label}: #{by.size} distinct"
    [ 3, 4, 5 ].each do |m|
      line = [ 0, 10_000, 20_000, 50_000 ].map do |floor|
        sets = by.select { |_, gs| gs.size >= m && gs.map { _1[:count] }.max >= floor }
        "floor #{floor}: #{sets.size} / #{sets.values.flatten.map { _1[:appid] }.uniq.size} cards"
      end
      puts "  min #{m}: #{line.join(' | ')}"
    end
    next unless label == "first developer"
    chosen = by.select { |_, gs| gs.size >= 3 && gs.map { _1[:count] }.max >= 20_000 }
    puts "  first dev, min 3, floor 20k, top 60: " + chosen.sort_by { -_2.size }.first(60).map { "#{display[_1]} (#{_2.size})" }.join(" | ")
    puts "  random 25: " + chosen.to_a.sample(25, random: Random.new(4)).map { "#{display[_1]} (#{_2.size})" }.join(" | ")
    dropped_by_floor = by.select { |_, gs| gs.size >= 3 && gs.map { _1[:count] }.max < 20_000 }
    puts "  dropped by the 20k floor (min 3), random 20 of #{dropped_by_floor.size}: " + dropped_by_floor.to_a.sample(20, random: Random.new(5)).map { "#{display[_1]} (#{_2.size})" }.join(" | ")
  end

  tag_names = q.("select tagid, name from steam_tags").to_h { |id, nm| [ id.to_i, nm ] }
  ids = tag_names.invert
  base = {
    "Souls-like" => [ "Souls-like" ], "Metroidvania" => [ "Metroidvania" ],
    "Roguelike" => [ "Roguelike", "Roguelite", "Action Roguelike", "Traditional Roguelike" ],
    "Deckbuilder" => [ "Deckbuilding", "Roguelike Deckbuilder", "Card Battler", "Card Game", "Trading Card Game" ],
    "Cosy" => [ "Cozy", "Wholesome", "Relaxing", "Life Sim" ], "Farming" => [ "Farming Sim", "Farming", "Agriculture" ],
    "Horror" => [ "Horror", "Survival Horror", "Psychological Horror" ], "Zombies" => [ "Zombies" ], "Pirates" => [ "Pirates" ],
    "Space" => [ "Space", "Space Sim", "Spaceships" ], "Cyberpunk" => [ "Cyberpunk" ],
    "FPS" => [ "FPS", "Boomer Shooter", "Arena Shooter", "Hero Shooter" ],
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
    "Lovecraftian" => [ "Lovecraftian" ]
  }
  optional = {
    "Simulation" => [ "Simulation", "Management", "Economy", "Job Simulator", "Hobby Sim", "Time Management" ],
    "Third-person shooter" => [ "Third-Person Shooter" ], "Idle" => [ "Incremental", "Idler", "Clicker" ],
    "Open world" => [ "Open World" ], "Walking simulator" => [ "Walking Simulator" ], "Party" => [ "Party Game", "Party", "Social Deduction" ],
    "VR" => [ "VR" ], "Comedy" => [ "Comedy", "Funny", "Memes", "Parody" ], "Adult" => [ "Sexual Content", "Nudity", "Hentai" ],
    "Action-adventure" => [ "Action-Adventure" ], "Physics" => [ "Physics" ], "Mechs" => [ "Mechs", "Robots" ],
    "Crime" => [ "Crime", "Heist" ], "Superhero" => [ "Superhero" ], "Cooking" => [ "Cooking", "Shop Keeper" ],
    "Female protagonist" => [ "Female Protagonist" ], "MMO" => [ "MMORPG", "Massively Multiplayer" ], "Battle royale" => [ "Battle Royale", "Extraction Shooter", "Looter Shooter" ]
  }
  resolve = ->(groups) { groups.transform_values { |list| list.filter_map { ids[_1] } } }
  base_ids = resolve.(base)
  opt_ids = resolve.(optional)
  puts "\n== THEMES: names not found #{(base.values + optional.values).flatten.reject { ids[_1] }.inspect}"
  in_any = ->(g, groups) { groups.values.any? { |list| (g[:top5] & list).any? } }
  ufos = games.reject { in_any.(_1, base_ids) }
  puts "base (#{base.size}): UFOs #{ufos.size} (#{pct.(ufos.size, n)})"
  adult = opt_ids["Adult"]
  puts "cards with an adult tag in top 5: #{games.count { (_1[:top5] & adult).any? }}; UFOs among them: #{ufos.count { (_1[:top5] & adult).any? }}"
  chosen = {}
  remaining = ufos
  pool = opt_ids.dup
  steps = []
  until pool.empty?
    name, list = pool.max_by { |_, l| remaining.count { (_1[:top5] & l).any? } }
    gain = remaining.count { (_1[:top5] & list).any? }
    remaining = remaining.reject { (_1[:top5] & list).any? }
    chosen[name] = list
    pool.delete(name)
    steps << "+#{name} (#{gain}) -> #{pct.(remaining.size, n)}"
  end
  puts "optional groups, greedy: " + steps.join(" | ")
  no_adult = opt_ids.except("Adult")
  left = ufos.reject { in_any.(_1, no_adult) }
  puts "UFOs left with every optional group but Adult: #{left.size} (#{pct.(left.size, n)})"
  leftover = Hash.new(0)
  left.each { |g| g[:top5].each { leftover[_1] += 1 } }
  puts "their top-5 tags (top 40): " + leftover.sort_by { -_2 }.first(40).map { "#{tag_names[_1]} #{_2}" }.join(" | ")
  puts "sample of them: " + left.sample(20, random: Random.new(6)).map { "#{_1[:name]} [#{_1[:top5].map { |t| tag_names[t] }.join(', ')}]" }.join(" ; ")

  puts "\n== THEME SIZES AND PACKS TO BRONZE/SILVER/GOLD (median of 31 runs, 5-card packs at published odds)"
  base_ids.merge(opt_ids).each do |name, list|
    set = games.select { (_1[:top5] & list).any? }
    puts "#{name}: #{set.size} cards, rarities #{rarity_mix.(set)}, packs #{packs_to.(set)}"
  end

  puts "\n== HALL OF FAME CANDIDATES (packs to bronze/silver/gold)"
  {
    "Intouchables >=97% & >=20k" => ->(g) { g[:positive] >= 97 && g[:count] >= 20_000 },
    "Intouchables >=96% & >=50k" => ->(g) { g[:positive] >= 96 && g[:count] >= 50_000 },
    "Pepites >=98% & <1000" => ->(g) { g[:positive] >= 98 && g[:count] < 1_000 },
    "Pepites >=97% & <1000" => ->(g) { g[:positive] >= 97 && g[:count] < 1_000 },
    "Mal-aimes 40-69% & >=20k" => ->(g) { g[:positive].between?(40, 69) && g[:count] >= 20_000 },
    "Mal-aimes 40-69% & >=10k" => ->(g) { g[:positive].between?(40, 69) && g[:count] >= 10_000 },
    "Phenomenes >=200k" => ->(g) { g[:count] >= 200_000 },
    "Phenomenes >=300k" => ->(g) { g[:count] >= 300_000 }
  }.each do |label, rule|
    set = games.select(&rule)
    puts "#{label}: #{set.size} cards, rarities #{rarity_mix.(set)}, packs #{packs_to.(set)}"
  end
end
