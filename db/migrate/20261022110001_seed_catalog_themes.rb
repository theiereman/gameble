# Seeds the themes and the classification of their tags from the list that
# was kept in code until now, with the broad tags dismissed as no theme, once,
# on a database that has no theme yet.
class SeedCatalogThemes < ActiveRecord::Migration[8.1]
  DEFAULT_THEMES = <<~YAML
      souls_like:
        en: Souls-like
        fr: Souls-like
        tags:
        - souls_like
      metroidvania:
        en: Metroidvania
        fr: Metroidvania
        tags:
        - metroidvania
      roguelike:
        en: Roguelike
        fr: Roguelike
        tags:
        - roguelike
        - roguelite
        - action_roguelike
        - traditional_roguelike
      deckbuilder:
        en: Deckbuilder
        fr: Deckbuilding
        tags:
        - deckbuilding
        - roguelike_deckbuilder
        - card_battler
        - card_game
        - trading_card_game
      cosy:
        en: Cosy
        fr: Cosy
        tags:
        - cozy
        - wholesome
        - relaxing
        - life_sim
      farming:
        en: Farming
        fr: Vie à la ferme
        tags:
        - farming_sim
        - farming
        - agriculture
      horror:
        en: Horror
        fr: Horreur
        tags:
        - horror
        - survival_horror
        - psychological_horror
        - lovecraftian
      zombies:
        en: Zombies
        fr: Zombies
        tags:
        - zombies
      pirates:
        en: Pirates
        fr: Pirates
        tags:
        - pirates
      space:
        en: Space
        fr: Espace
        tags:
        - space
        - space_sim
        - spaceships
      cyberpunk:
        en: Cyberpunk
        fr: Cyberpunk
        tags:
        - cyberpunk
      fps:
        en: FPS
        fr: FPS
        tags:
        - fps
        - boomer_shooter
        - arena_shooter
        - hero_shooter
      third_person_shooter:
        en: Third-person shooter
        fr: Tir à la troisième personne
        tags:
        - third_person_shooter
      platformer:
        en: Platformer
        fr: Plates-formes
        tags:
        - platformer
        - 2d_platformer
        - 3d_platformer
        - precision_platformer
        - puzzle_platformer
      puzzle:
        en: Puzzle
        fr: Réflexion
        tags:
        - puzzle
        - logic
      racing:
        en: Racing
        fr: Course
        tags:
        - racing
        - driving
        - automobile_sim
      sports:
        en: Sports
        fr: Sport
        tags:
        - sports
        - football_soccer
        - football_american
        - basketball
        - golf
        - skateboarding
      strategy:
        en: Strategy
        fr: Stratégie
        tags:
        - strategy
        - rts
        - turn_based_strategy
        - grand_strategy
        - 4x
        - wargame
      rpg:
        en: RPG
        fr: RPG
        tags:
        - rpg
        - jrpg
        - crpg
        - action_rpg
        - party_based_rpg
        - tactical_rpg
        - strategy_rpg
      survival:
        en: Survival
        fr: Survie
        tags:
        - survival
        - open_world_survival_craft
      city_builder:
        en: City builder
        fr: City builder
        tags:
        - city_builder
        - colony_sim
        - base_building
      visual_novel:
        en: Visual novel
        fr: Visual novel
        tags:
        - visual_novel
        - interactive_fiction
        - dating_sim
        - choose_your_own_adventure
      point_and_click:
        en: Point & click
        fr: Point & click
        tags:
        - point_click
        - hidden_object
      adventure:
        en: Adventure
        fr: Aventure
        tags:
        - adventure
      fighting:
        en: Fighting
        fr: Combat
        tags:
        - fighting
        - 2d_fighter
        - 3d_fighter
        - beat_em_up
        - martial_arts
      stealth:
        en: Stealth
        fr: Infiltration
        tags:
        - stealth
      rhythm:
        en: Rhythm
        fr: Rythme
        tags:
        - rhythm
        - music
      shoot_em_up:
        en: Shoot 'em up
        fr: Shoot 'em up
        tags:
        - shoot_em_up
        - bullet_hell
        - twin_stick_shooter
        - bullet_heaven
      hack_and_slash:
        en: Hack and slash
        fr: Hack and slash
        tags:
        - hack_and_slash
        - character_action_game
        - spectacle_fighter
      post_apocalyptic:
        en: Post-apocalyptic
        fr: Post-apocalyptique
        tags:
        - post_apocalyptic
      war:
        en: War
        fr: Guerre
        tags:
        - world_war_ii
        - world_war_i
        - military
        - war
      medieval:
        en: Medieval
        fr: Médiéval
        tags:
        - medieval
      anime:
        en: Anime
        fr: Anime
        tags:
        - anime
      sandbox:
        en: Sandbox
        fr: Bac à sable
        tags:
        - sandbox
      tower_defense:
        en: Tower defense
        fr: Tower defense
        tags:
        - tower_defense
      mystery:
        en: Mystery
        fr: Enquête
        tags:
        - detective
        - mystery
        - investigation
      simulation:
        en: Simulation
        fr: Simulation
        tags:
        - simulation
        - management
        - economy
        - job_simulator
        - hobby_sim
        - time_management
        - cooking
        - shop_keeper
      comedy:
        en: Comedy
        fr: Humour
        tags:
        - comedy
        - funny
        - memes
        - parody
      open_world:
        en: Open world
        fr: Monde ouvert
        tags:
        - open_world
      idle:
        en: Idle
        fr: Idle
        tags:
        - incremental
        - idler
        - clicker
      walking_simulator:
        en: Walking simulator
        fr: Walking simulator
        tags:
        - walking_simulator
      vr:
        en: VR
        fr: Réalité virtuelle
        tags:
        - vr
      adult:
        en: Adult
        fr: Adulte
        tags:
        - sexual_content
        - nudity
        - hentai
    YAML

  DISMISSED_TAGS = %w[action casual indie singleplayer multiplayer free_to_play].freeze

  def up
    return if select_value("SELECT 1 FROM catalog_themes LIMIT 1")

    safety_assured { seed }
  end

  def down
    safety_assured do
      execute("DELETE FROM catalog_tag_classifications")
      execute("DELETE FROM catalog_themes")
    end
  end

  private

  def seed
    YAML.safe_load(DEFAULT_THEMES).each do |key, theme|
      id = select_value(<<~SQL.squish)
        INSERT INTO catalog_themes (token, key, name_en, name_fr, created_at, updated_at)
        VALUES (#{quote(SecureRandom.base58(24))}, #{quote(key)}, #{quote(theme["en"])}, #{quote(theme["fr"])}, now(), now())
        RETURNING id
      SQL
      theme["tags"].each do |tag_key|
        execute(<<~SQL.squish)
          INSERT INTO catalog_tag_classifications (tag_key, theme_id, not_a_theme, created_at, updated_at)
          VALUES (#{quote(tag_key)}, #{id}, false, now(), now())
        SQL
      end
    end
    DISMISSED_TAGS.each do |tag_key|
      execute(<<~SQL.squish)
        INSERT INTO catalog_tag_classifications (tag_key, theme_id, not_a_theme, created_at, updated_at)
        VALUES (#{quote(tag_key)}, NULL, true, now(), now())
      SQL
    end
  end
end
