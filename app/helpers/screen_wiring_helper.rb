module ScreenWiringHelper
  def screen_actions(root, children)
    children.flat_map do |child, events|
      events.map { |event, method| "#{child}:#{event}->#{root}##{method}" }
    end.join(" ")
  end

  def screen_outlets(root, children)
    children.uniq.to_h do |child|
      [ :"#{root.underscore}_#{child.underscore}_outlet", "##{root} [data-controller~='#{child}']" ]
    end
  end

  def screen_strings(scope)
    t(scope).deep_transform_keys { it.to_s.camelize(:lower) }
  end
end
