module GoalsHelper
  def goal_set_name(target)
    return SetLabel.for(target.set) unless target.custom?

    target.steam_library? ? t("custom_sets.library.name") : target.custom_set_name
  end

  def goal_album_path(target)
    target.custom? ? custom_set_path(token: target.custom_set_token) : library_set_path(kind: target.kind, key: target.key)
  end

  def goal_aim_params(target)
    target.custom? ? { custom_set: target.custom_set_token } : { kind: target.kind, key: target.key }
  end

  def goal_kind_name(target)
    target.custom? ? t("library.entry.goals.custom_kind") : set_kind_name(target.kind)
  end

  def goal_bookmark(number, size: nil, hollow: false)
    classes = [ "goal-bookmark", ("goal-bookmark--#{size}" if size), (hollow ? "goal-bookmark--hollow" : "goal-tone--#{number}") ]
    tag.span(tag.span(number, class: "goal-bookmark__shape"), class: classes, aria: { hidden: true })
  end

  def goal_name(goal)
    t("goals.name", number: goal.position, set: goal_set_name(goal))
  end

  def goal_card_words(goals)
    goals.map { t("goals.card_words", number: it.position, set: goal_set_name(it)) }.join(", ")
  end

  def set_tile_goal(tile, goals)
    goals.find { tile.own? ? it.custom_set_token == tile.own_set.token : !it.custom? && it.kind == tile.set.kind && it.key == tile.set.key }
  end

  def goal_row_sentence(need)
    t("library.entry.goals.row", number: need.position, **goal_row_words(need))
  end

  def goal_suggestion_sentence(set, standing)
    left = standing.total - standing.held
    [ set_progress_sentence(set, standing), t("library.entry.goals.suggestion_left", count: left, missing: number_with_delimiter(left)) ].join(", ")
  end

  def profile_goal_row_sentence(need)
    t("public_profiles.show.goals.row", **goal_row_words(need))
  end

  def goal_free_slot(goals)
    taken = goals.map(&:position)
    Game::Goal::POSITIONS.find { !taken.include?(it) }
  end

  private
    def goal_row_words(need)
      standing = need.to_set_standing
      count = t("library.set_progress.count", count: standing.held, owned: number_with_delimiter(standing.held), total: number_with_delimiter(standing.total))
      { set: goal_set_name(need), kind: goal_kind_name(need).downcase, count:, next: goal_next_words(standing) }
    end

    def goal_next_words(standing)
      return t("library.set_progress.complete") if standing.complete?

      missing = number_with_delimiter(standing.missing)
      return t("library.entry.goals.next_complete", missing:) if standing.next_tier == Catalog::SetTier::COMPLETE

      t("library.entry.goals.next", missing:, tier: set_tier_name(standing.next_tier))
    end
end
