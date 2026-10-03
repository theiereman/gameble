module Steam
  # The genres of the tomes (catalog-and-rarity.md, Sets): a curated list of
  # Steam genre tags, by tagid (GetTagList), each with the genre key Catalog
  # names its tomes with (catalog.genres.* in the locales).
  #
  # A game's genres are its listed tags in its own order, most-voted first
  # (Steam::DetailsPolicy keeps tag_ids heaviest first, ties by tagid), so
  # its first genre, the tome it sits in, is its most-voted listed tag. A
  # game with none of them has no genre and sits in no tome.
  #
  #   Steam::GenreTags.call([ 492, 1664, 1663 ])
  #   # => ["puzzle", "fps"]
  module GenreTags
    GENRES = {
      1663 => "fps",
      1625 => "platformer",
      1628 => "metroidvania",
      1664 => "puzzle",
      1667 => "horror",
      1716 => "roguelike",
      29482 => "souls_like",
      1646 => "hack_and_slash",
      1743 => "fighting",
      699 => "racing",
      701 => "sports",
      9 => "strategy",
      122 => "rpg",
      1662 => "survival",
      599 => "simulation",
      4328 => "city_builder",
      3810 => "sandbox",
      3799 => "visual_novel",
      1698 => "point_and_click",
      1666 => "card_game"
    }.freeze

    # The genre keys of `tag_ids`, in their order: unlisted tagids dropped.
    def self.call(tag_ids)
      Array(tag_ids).filter_map { |tagid| GENRES[tagid.to_i] }.uniq
    end
  end
end
