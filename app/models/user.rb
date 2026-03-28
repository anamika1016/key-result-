class User < ApplicationRecord
  # Devise modules for authentication
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_one :employee_detail
  has_one_attached :avatar
  has_many :user_training_assignments, dependent: :destroy
  has_many :assigned_trainings, through: :user_training_assignments, source: :training
  has_many :user_training_progresses, dependent: :destroy


  # Server-side avatar validation
  validate :avatar_content_type, :avatar_file_size

  def avatar_content_type
    if avatar.attached? && !avatar.content_type.in?(%w[image/jpeg image/jpg image/png image/gif image/webp])
      errors.add(:avatar, "must be a JPEG, PNG, GIF, or WEBP image")
    end
  end

  def avatar_file_size
    if avatar.attached? && avatar.blob.byte_size > 10.megabytes
      errors.add(:avatar, "file size must be less than 10MB")
    end
  end

  ROLES = %w[employee hod l1_employer l2_employer]

  # Auto-strip employee_code before save
  before_validation :sanitize_employee_code

  def sanitize_employee_code
    self.employee_code = employee_code.strip if employee_code.present?
  end

  # Role helpers
  def employee?
    role == "employee"
  end

  def hod?
    role == "hod"
  end

  def l1_employer?
    role == "l1_employer"
  end

  def l2_employer?
    role == "l2_employer"
  end

  def self.find_for_database_authentication(warden_conditions)
    conditions = warden_conditions.dup
    login = conditions.delete(:login)
    if login.present?
      value = login.strip.downcase
      where(conditions).where([ "lower(email) = :value OR lower(employee_code) = :value", { value: value } ]).first
    else
      # Fallback to standard email lookup if no login parameter
      where(conditions).first
    end
  end

  def name
    email
  end
end
