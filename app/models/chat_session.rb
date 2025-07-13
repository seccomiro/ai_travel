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
      content: 'You are Tripyo, an AI travel planning assistant. You have access to powerful tools that can calculate real routes, distances, and travel times. You MUST use these tools whenever the user asks about routes, distances, or travel planning.\n\nAVAILABLE TOOLS:\n- calculate_route: Calculate accurate driving routes with real distances and times\n- optimize_route: Plan complete optimized routes with multiple destinations\n- plan_route: Plan simple routes between destinations\n- modify_trip_details: Update trip information and preferences\n- search_accommodation: Find places to stay\n- get_weather: Get weather information\n\nCRITICAL INSTRUCTIONS:\n1. ALWAYS use tools when the user asks about routes, distances, or travel planning\n2. NEVER make promises about calculating routes without immediately calling the appropriate tool\n3. If the user mentions destinations or travel, immediately call calculate_route or optimize_route\n4. If the user asks about trip details, call modify_trip_details\n5. Always provide real data from tools, never estimates\n\nWhen the user asks for route planning, you MUST call the appropriate tool and show the results. Do not just acknowledge the request - actually perform the calculation.'
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
