require "test_helper"

class SectionComponentTest < ViewComponent::TestCase
  test "a group heading names the section and heads its panels" do
    render_inline(SectionComponent.new(title: "Capsules", id: "rules-capsules")) { "<p>Panels</p>".html_safe }

    assert_selector "section.section[aria-labelledby=rules-capsules] > header h2#rules-capsules.section__title", text: "Capsules"
    assert_selector "section.section > p", text: "Panels"
    assert_no_selector ".section__aside"
  end

  test "the right slot carries a count or a see-all link" do
    render_inline(SectionComponent.new(title: "My sets", id: "my-sets")) do |section|
      section.with_aside { "12" }
    end

    assert_selector ".section__head .section__aside", text: "12"
  end
end
