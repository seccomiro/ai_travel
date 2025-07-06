class ChatMessage < ApplicationRecord
  belongs_to :chat_session

  # Callbacks
  after_initialize :set_defaults

  # Validations
  validates :role, inclusion: { in: %w[user assistant system] }
  validates :content, presence: true
  validates :chat_session, presence: true

  # Scopes
  scope :by_role, ->(role) { where(role: role) }
  scope :recent, -> { order(created_at: :desc) }
  scope :user_messages, -> { where(role: 'user') }
  scope :assistant_messages, -> { where(role: 'assistant') }
  scope :system_messages, -> { where(role: 'system') }

  # Instance methods
  def user_message?
    role == 'user'
  end

  def assistant_message?
    role == 'assistant'
  end

  def system_message?
    role == 'system'
  end

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
