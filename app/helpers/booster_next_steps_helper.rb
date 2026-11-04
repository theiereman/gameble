module BoosterNextStepsHelper
  NextStep = Data.define(:key, :icon, :path, :hook)

  def booster_next_steps(steps)
    [
      NextStep.new(key: :sets, icon: "tab-sets", path: library_path, hook: steps.closest_set&.then { booster_set_hook(it) }),
      NextStep.new(key: :social, icon: "tab-friends", path: friends_path, hook: steps.friend&.then { booster_friend_hook(it) }),
      NextStep.new(key: :me, icon: "tab-me", path: me_path, hook: (booster_rewards_hook(steps.rewards) if steps.rewards.positive?))
    ]
  end

  private
    def booster_set_hook(closest)
      t("booster.next_steps.set_hook", set: SetLabel.for(closest.set), next: goal_next_words(closest.standing))
    end

    def booster_friend_hook(friend)
      t("booster.next_steps.social_hook", name: friend_name(friend))
    end

    def booster_rewards_hook(rewards)
      t("booster.next_steps.me_hook", count: rewards, number: number_with_delimiter(rewards))
    end
end
