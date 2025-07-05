class Trip < ApplicationRecord
  belongs_to :user
  
  # Validations
  validates :title, presence: true, length: { maximum: 255 }
  validates :status, inclusion: { in: %w[planning active completed cancelled] }
  validates :start_date, :end_date, presence: true, if: :dates_required?
  validate :end_date_after_start_date, if: :both_dates_present?

  # Scopes
  scope :planning, -> { where(status: 'planning') }
  scope :active, -> { where(status: 'active') }
  scope :completed, -> { where(status: 'completed') }
  scope :recent, -> { order(created_at: :desc) }

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

  def duration_days
    return nil unless start_date && end_date
    (end_date - start_date).to_i + 1
  end

  def estimated_total_cost
    # This will be calculated from trip segments once we create them
    trip_data.dig('estimated_cost') || 0
  end

  private

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
