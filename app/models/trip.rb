class Trip < ApplicationRecord
  belongs_to :user
  has_many :chat_sessions, dependent: :destroy

  # Callbacks
  after_initialize :set_defaults

  # Validations
  validates :title, presence: true, length: { maximum: 255 }
  validates :status, inclusion: { in: %w[planning active completed cancelled] }
  validates :start_date, :end_date, presence: true, if: :dates_required?
  validate :end_date_after_start_date, if: :both_dates_present?

  # JSON attributes
  attribute :trip_data, :json, default: {}
  attribute :sharing_settings, :json, default: {}
  attribute :is_public, :boolean, default: false

  # Enums
  enum :status, {
    planning: 'planning',
    active: 'active',
    completed: 'completed',
    cancelled: 'cancelled'
  }

  # Scopes
  scope :planning, -> { where(status: 'planning') }
  scope :active, -> { where(status: 'active') }
  scope :completed, -> { where(status: 'completed') }
  scope :public_trips, -> { where(is_public: true) }
  scope :by_user, ->(user) { where(user: user) }
  scope :recent, -> { order(created_at: :desc) }

  # Alias for compatibility with views
  def name
    title
  end

  def name=(value)
    self.title = value
  end

  # Instance methods
  def planning?
    status == 'planning'
  end

  def active?
    status == 'active'
  end

  def completed?
    status == 'completed'
  end

  def duration_in_days
    return nil unless start_date && end_date
    (end_date - start_date).to_i + 1
  end

  def duration_days
    duration_in_days
  end

  def estimated_total_cost
    # This will be calculated from trip segments once we create them
    trip_data.dig('estimated_cost') || 0
  end

  def can_be_edited_by?(user)
    return false unless user
    self.user == user
  end

  def status_badge_class
    case status
    when 'planning'
      'bg-primary'
    when 'active'
      'bg-success'
    when 'completed'
      'bg-secondary'
    else
      'bg-secondary'
    end
  end

  def is_current?
    status == 'active'
  end

  def add_trip_data(key, value)
    self.trip_data ||= {}
    self.trip_data[key] = value
  end

  def active_chat_session
    chat_sessions.active.first
  end

  def create_chat_session(user)
    chat_sessions.create!(user: user, status: 'active')
  end

  def has_active_chat_session?
    chat_sessions.active.exists?
  end

  private

  def set_defaults
    self.status ||= 'planning'
    self.trip_data ||= {}
    self.sharing_settings ||= {}
    # is_public has a database default of false
  end

  def dates_required?
    # For now, require dates for active and completed trips
    %w[active completed].include?(status)
  end

  def both_dates_present?
    start_date.present? && end_date.present?
  end

  def end_date_after_start_date
    return unless both_dates_present?

    if end_date < start_date
      errors.add(:end_date, 'must be after start date')
    end
  end
end
