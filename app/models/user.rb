class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Validations
  validates :preferred_language, inclusion: { in: %w[en es] }
  validates :first_name, :last_name, presence: true, length: { maximum: 100 }

  # Associations
  has_many :trips, dependent: :destroy
  # has_many :user_preferences, dependent: :destroy

  # Instance methods
  def full_name
    "#{first_name} #{last_name}".strip
  end

  def display_name
    full_name.present? ? full_name : email
  end
end
