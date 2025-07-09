class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  after_initialize :set_default_preferred_language

  validates :preferred_language, inclusion: { in: %w[en es] }
  validates :first_name, :last_name, presence: true, length: { maximum: 100 }

  has_many :trips, dependent: :destroy
  # has_many :user_preferences, dependent: :destroy

  def full_name
    "#{first_name} #{last_name}".strip
  end

  def display_name
    full_name.present? ? full_name : email
  end

  def initials
    if first_name.present? && last_name.present?
      "#{first_name[0]}#{last_name[0]}".upcase
    else
      email[0].upcase
    end
  end

  private

  def set_default_preferred_language
    self.preferred_language ||= 'en'
  end
end
