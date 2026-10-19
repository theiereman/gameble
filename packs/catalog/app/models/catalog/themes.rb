module Catalog
  # The themes a card can belong to, each grouping the Steam tags that name
  # it, by English tag name; a theme's name is `catalog.themes.<key>` in the
  # locales. A game joins every theme one of its most-voted tags belongs
  # to; a game with none joins the UFOs. The first theme in vote order is the
  # card's main theme, shown as its genre.
  #
  #   Catalog::Themes.of([ "Indie", "Roguelite", "Deckbuilding", "Horror" ])
  #   # => ["roguelike", "deckbuilder", "horror"]
  #   Catalog::Themes.key?("rpg") # => true
  module Themes
    TAGS = {
      "souls_like" => [ "Souls-like" ],
      "metroidvania" => [ "Metroidvania" ],
      "roguelike" => [ "Roguelike", "Roguelite", "Action Roguelike", "Traditional Roguelike" ],
      "deckbuilder" => [ "Deckbuilding", "Roguelike Deckbuilder", "Card Battler", "Card Game", "Trading Card Game" ],
      "cosy" => [ "Cozy", "Wholesome", "Relaxing", "Life Sim" ],
      "farming" => [ "Farming Sim", "Farming", "Agriculture" ],
      "horror" => [ "Horror", "Survival Horror", "Psychological Horror", "Lovecraftian" ],
      "zombies" => [ "Zombies" ],
      "pirates" => [ "Pirates" ],
      "space" => [ "Space", "Space Sim", "Spaceships" ],
      "cyberpunk" => [ "Cyberpunk" ],
      "fps" => [ "FPS", "Boomer Shooter", "Arena Shooter", "Hero Shooter" ],
      "third_person_shooter" => [ "Third-Person Shooter" ],
      "platformer" => [ "Platformer", "2D Platformer", "3D Platformer", "Precision Platformer", "Puzzle Platformer" ],
      "puzzle" => [ "Puzzle", "Logic" ],
      "racing" => [ "Racing", "Driving", "Automobile Sim" ],
      "sports" => [ "Sports", "Football (Soccer)", "Football (American)", "Basketball", "Golf", "Skateboarding" ],
      "strategy" => [ "Strategy", "RTS", "Turn-Based Strategy", "Grand Strategy", "4X", "Wargame" ],
      "rpg" => [ "RPG", "JRPG", "CRPG", "Action RPG", "Party-Based RPG", "Tactical RPG", "Strategy RPG" ],
      "survival" => [ "Survival", "Open World Survival Craft" ],
      "city_builder" => [ "City Builder", "Colony Sim", "Base Building" ],
      "visual_novel" => [ "Visual Novel", "Interactive Fiction", "Dating Sim", "Choose Your Own Adventure" ],
      "point_and_click" => [ "Point & Click", "Hidden Object" ],
      "fighting" => [ "Fighting", "2D Fighter", "3D Fighter", "Beat 'em up", "Martial Arts" ],
      "stealth" => [ "Stealth" ],
      "rhythm" => [ "Rhythm", "Music" ],
      "shoot_em_up" => [ "Shoot 'Em Up", "Bullet Hell", "Twin Stick Shooter", "Bullet Heaven" ],
      "hack_and_slash" => [ "Hack and Slash", "Character Action Game", "Spectacle fighter" ],
      "post_apocalyptic" => [ "Post-apocalyptic" ],
      "war" => [ "World War II", "World War I", "Military", "War" ],
      "medieval" => [ "Medieval" ],
      "anime" => [ "Anime" ],
      "sandbox" => [ "Sandbox" ],
      "tower_defense" => [ "Tower Defense" ],
      "mystery" => [ "Detective", "Mystery", "Investigation" ],
      "simulation" => [ "Simulation", "Management", "Economy", "Job Simulator", "Hobby Sim", "Time Management", "Cooking", "Shop Keeper" ],
      "comedy" => [ "Comedy", "Funny", "Memes", "Parody" ],
      "open_world" => [ "Open World" ],
      "idle" => [ "Incremental", "Idler", "Clicker" ],
      "walking_simulator" => [ "Walking Simulator" ],
      "vr" => [ "VR" ],
      "adult" => [ "Sexual Content", "Nudity", "Hentai" ]
    }.freeze

    # The share of a season's cards the UFOs should stay under.
    UFO_SHARE_LIMIT = 0.05

    THEME_OF_TAG = TAGS.flat_map { |theme, tags| tags.map { |tag| [ tag, theme ] } }.to_h.freeze
    private_constant :THEME_OF_TAG

    def self.keys
      TAGS.keys
    end

    def self.key?(key)
      TAGS.key?(key)
    end

    # The themes of `tag_names`, in the tags' order, each once; a tag of no
    # theme is skipped.
    def self.of(tag_names)
      tag_names.filter_map { |name| THEME_OF_TAG[name] }.uniq
    end
  end
end
