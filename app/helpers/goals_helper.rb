module GoalsHelper
  def goal_set_name(target)
    target.custom? ? target.custom_set_name : SetLabel.for(target.set)
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

  def goal_row_sentence(need)
    standing = need.to_set_standing
    count = t("library.set_progress.count", count: standing.held, owned: number_with_delimiter(standing.held), total: number_with_delimiter(standing.total))
    t("library.entry.goals.row", number: need.position, set: goal_set_name(need), kind: goal_kind_name(need).downcase, count:, next: goal_next_words(standing))
  end

  def goal_free_slot(goals)
    taken = goals.map(&:position)
    Game::Goal::POSITIONS.find { !taken.include?(it) }
  end

  private
    def goal_next_words(standing)
      return t("library.set_progress.complete") if standing.complete?

      missing = number_with_delimiter(standing.missing)
      return t("library.entry.goals.next_complete", missing:) if standing.next_tier == Catalog::SetTier::COMPLETE

      t("library.entry.goals.next", missing:, tier: set_tier_name(standing.next_tier))
    end
end
