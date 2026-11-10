require_relative "singleton_stub"

# Runs a test with or without a Claude API key, and with Claude's answers replaced.
module ClaudeWriterStubs
  include SingletonStub

  def self.included(test_case)
    test_case.setup { @anthropic_key_was = Rails.configuration.x.anthropic.api_key }
    test_case.teardown { Rails.configuration.x.anthropic.api_key = @anthropic_key_was }
  end

  def with_anthropic_key(key = "test-key")
    Rails.configuration.x.anthropic.api_key = key
  end

  def without_anthropic_key
    Rails.configuration.x.anthropic.api_key = nil
  end

  # A stand-in for Anthropic::Client whose beta messages answer `reply` and keep the request they got.
  class FakeClaude
    Message = Data.define(:stop_reason, :content)
    Block = Data.define(:type, :text)

    attr_reader :requests

    def initialize(answer, stop_reason: :end_turn)
      @answer = answer
      @stop_reason = stop_reason
      @requests = []
    end

    def beta = self
    def messages = self

    def create(**request)
      @requests << request
      raise @answer if @answer.is_a?(Exception)

      Message.new(stop_reason: @stop_reason, content: [ Block.new(type: :thinking, text: nil), Block.new(type: :text, text: @answer) ])
    end
  end

  def with_claude(answer, **options)
    fake = FakeClaude.new(answer.is_a?(Hash) ? answer.to_json : answer, **options)
    stub_singleton(Accounts::ClaudeWriter, :client, -> { fake }) { yield fake }
  end
end
