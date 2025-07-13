class ChatMessage < ApplicationRecord
  belongs_to :chat_session

  after_initialize :set_defaults

  validates :role, inclusion: { in: %w[user assistant system] }
  validates :content, presence: true
  validates :chat_session, presence: true

  enum :role, {
    user: 'user',
    assistant: 'assistant',
    system: 'system',
  }, prefix: :from, validate: true

  scope :recent, -> { order(created_at: :desc) }

  def formatted_content
    # For now, just return content. Later we can add markdown parsing
    content
  end

  def metadata_value(key)
    metadata&.dig(key)
  end

  def set_metadata(key, value)
    self.metadata ||= {}
    self.metadata[key] = value
  end

  def ai_tool_calls
    metadata_value('tool_calls') || []
  end

  def ai_tool_results
    metadata_value('tool_results') || []
  end

  def has_tool_calls?
    ai_tool_calls.any?
  end

  def has_tool_results?
    ai_tool_results.any?
  end

  private

  def set_defaults
    self.metadata ||= {}
  end
end
