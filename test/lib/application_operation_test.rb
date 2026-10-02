require "test_helper"

module Sample
  class WidgetCreated < RubyEventStore::Event; end

  class Widget < ActiveRecord::Base
    self.table_name = "sample_widgets"
  end

  class CreateWidget < ApplicationOperation
    def call(name:, reject: false)
      transaction do
        widget = step create_widget(name)
        step publish(Sample::WidgetCreated.new(data: { widget_id: widget.id }), stream_name: "Sample::Widget$#{widget.id}")
        step reject ? Failure(:rejected) : Success(widget)
      end
    end

    private

    def create_widget(name)
      Success(Widget.create!(name: name))
    end
  end
end

class ApplicationOperationTest < ActiveSupport::TestCase
  setup do
    # PostgreSQL DDL is transactional: the test transaction drops this table.
    ActiveRecord::Base.connection.create_table(:sample_widgets) { |t| t.string :name, null: false }
    Sample::Widget.reset_column_information
  end

  def event_store
    Rails.configuration.event_store
  end

  def widget_created_events
    event_store.read.of_type(Sample::WidgetCreated).to_a
  end

  test "a success commits the row and its event in the expected stream" do
    result = Sample::CreateWidget.new.call(name: "Portal")

    assert result.success?
    widget = result.value!
    assert_equal "Portal", Sample::Widget.find(widget.id).name

    events = event_store.read.stream("Sample::Widget$#{widget.id}").to_a
    assert_equal 1, events.size
    assert_instance_of Sample::WidgetCreated, events.first
    assert_equal({ widget_id: widget.id }, events.first.data)
  end

  test "a failure after writing rolls back the row and the event" do
    result = Sample::CreateWidget.new.call(name: "Portal", reject: true)

    assert result.failure?
    assert_equal :rejected, result.failure
    assert_equal 0, Sample::Widget.count
    assert_empty widget_created_events
  end

  test "a failure code maps to a locale key under the operation's pack" do
    assert_equal "errors.sample.rejected", Sample::CreateWidget.failure_key(:rejected)
  end

  test "a failure message is the translation of its key in the current locale" do
    original_backend = I18n.backend
    I18n.backend = I18n::Backend::Simple.new
    I18n.backend.store_translations(:en, errors: { sample: { rejected: "The widget was rejected." } })

    I18n.with_locale(:en) do
      assert_equal "The widget was rejected.", Sample::CreateWidget.failure_message(:rejected)
    end
  ensure
    I18n.backend = original_backend
  end

  test "a failure message on a missing key raises" do
    assert_raises(I18n::MissingTranslationData) do
      Sample::CreateWidget.failure_message(:unknown_code)
    end
  end
end
