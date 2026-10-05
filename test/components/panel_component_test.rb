require "test_helper"

class PanelComponentTest < ViewComponent::TestCase
  test "a panel is a div by default" do
    render_inline(PanelComponent.new) { "Stand ready" }

    assert_selector "div.panel", text: "Stand ready"
    assert_no_selector ".panel--quiet, .panel--brackets"
  end

  test "it takes another tag" do
    render_inline(PanelComponent.new(tag: :p)) { "Stand ready" }

    assert_selector "p.panel", text: "Stand ready"
    assert_no_selector "div.panel"
  end

  test "a quiet panel with corner brackets" do
    render_inline(PanelComponent.new(tag: :section, quiet: true, brackets: true)) { "Goal" }

    assert_selector "section.panel.panel--quiet.panel--brackets", text: "Goal"
  end

  test "other attributes pass through, classes added" do
    render_inline(PanelComponent.new(tag: :section, class: "goal", aria: { labelledby: "goal-heading" })) { "Goal" }

    assert_selector "section.panel.goal[aria-labelledby=goal-heading]"
  end
end
