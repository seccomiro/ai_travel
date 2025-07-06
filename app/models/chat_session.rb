class ChatSession < ApplicationRecord
  belongs_to :trip
  belongs_to :user
  has_many :chat_messages, dependent: :destroy

  # Callbacks
  after_initialize :set_defaults

  # Validations
  validates :status, inclusion: { in: %w[active completed archived] }
  validates :trip, presence: true
  validates :user, presence: true

  # Enums
  enum :status, {
    active: 'active',
    completed: 'completed',
    archived: 'archived'
  }

  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_trip, ->(trip) { where(trip: trip) }
  scope :by_user, ->(user) { where(user: user) }

  # Instance methods
  def active?
    status == 'active'
  end

  def completed?
    status == 'completed'
  end

  def archived?
    status == 'archived'
  end

  def message_count
    chat_messages.count
  end

  def last_message
    chat_messages.order(created_at: :desc).first
  end

  def user_messages
    chat_messages.where(role: 'user')
  end

  def assistant_messages
    chat_messages.where(role: 'assistant')
  end

  def system_messages
    chat_messages.where(role: 'system')
  end

  def update_context_summary(summary)
    update(context_summary: summary)
  end

  def conversation_history
    chat_messages.order(:created_at).pluck(:role, :content)
  end

  def conversation_for_ai
    # Start with a system message to set context
    system_message = {
      role: 'system',
      content: "You are Tripyo, an AI travel planning assistant. Help users plan their trips by providing personalized recommendations for destinations, accommodations, activities, and transportation. Use the available tools to get real-time information about weather, accommodation options, and route planning. Be conversational, helpful, and proactive in suggesting next steps for trip planning."
    }
    
    # Add conversation history
    messages = chat_messages.order(:created_at).map do |message|
      { role: message.role, content: message.content }
    end
    
    [system_message] + messages
  end

  private

  def set_defaults
    self.status ||= 'active'
    self.context_summary ||= ''
  end
end
