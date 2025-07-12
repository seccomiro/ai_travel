class ChatSession < ApplicationRecord
  belongs_to :trip
  has_one :user, through: :trip
  has_many :chat_messages, dependent: :destroy

  after_initialize :set_defaults

  validates :status, inclusion: { in: %w[active completed archived] }
  validates :trip, presence: true

  enum :status, {
    active: 'active',
    completed: 'completed',
    archived: 'archived',
  }, prefix: true, validate: true

  scope :active, -> { where(status: 'active') }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_trip, ->(trip) { where(trip: trip) }
  scope :by_user, ->(user) { joins(:trip).where(trips: { user: user }) }

  def message_count
    chat_messages.count
  end

  def last_message
    chat_messages.order(created_at: :desc).first
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
      content: 'You are Tripyo, an AI travel planning assistant. Help users plan their trips by providing personalized recommendations for destinations, accommodations, activities, and transportation. Use the available tools to get real-time information about weather, accommodation options, and route planning. Be conversational, helpful, and proactive in suggesting next steps for trip planning.

IMPORTANT ROUTE PLANNING RULES:
1. For any driving segment, ALWAYS use the calculate_route tool to get real-world distance and time. Never estimate these values yourself.
2. If a segment exceeds the user\'s daily driving preferences (max_daily_drive_h or max_daily_distance_km), use the tool\'s suggestions to split the segment into multiple days with realistic intermediate stops.
3. Always validate that each segment fits the user\'s preferences before presenting the final route.
4. If you need to split a long segment, suggest specific towns or cities as intermediate stops that are actually along the route.
5. Present only the final, validated route to the user - do not show segments that exceed their preferences.',
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
