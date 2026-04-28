class UserQuiz < ApplicationRecord
  IMPORTABLE_FIELDS = %w[
    employee_code
    name
    email
    mobile_number
    designation
    branch
    sub_branch
    password
  ].freeze

  belongs_to :user, optional: true
  belongs_to :quiz, optional: true
  has_many :quiz_submissions, dependent: :destroy

  validates :employee_code, :name, :email, :password, presence: true
  validates :employee_code, uniqueness: { case_sensitive: false }

  before_validation :normalize_fields
  before_validation :attach_matching_user

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  private

  def normalize_fields
    self.employee_code = employee_code.to_s.strip.presence
    self.name = name.to_s.strip.presence
    self.email = email.to_s.strip.downcase.presence
    self.mobile_number = mobile_number.to_s.strip.presence
    self.designation = designation.to_s.strip.presence
    self.branch = branch.to_s.strip.presence
    self.sub_branch = sub_branch.to_s.strip.presence
    self.password = password.to_s.strip.presence
  end

  def attach_matching_user
    return if employee_code.blank? && email.blank?

    self.user =
      User.find_by(employee_code: employee_code) ||
      User.find_by("LOWER(email) = ?", email.to_s.downcase)
  end

  public

  def valid_quiz_password?(raw_password)
    password.to_s == raw_password.to_s.strip
  end

  def employee_detail_record
    @employee_detail_record ||= begin
      normalized_code = employee_code.to_s.strip
      if normalized_code.blank?
        nil
      else
        EmployeeDetail.find_by(employee_code: normalized_code) ||
          EmployeeDetail.where("employee_code LIKE ?", "#{ActiveRecord::Base.sanitize_sql_like(normalized_code)}\\_%").order(:id).first
      end
    end
  end

  def display_name
    name.presence || employee_detail_record&.employee_name || user&.email
  end

  def display_designation
    designation.presence || employee_detail_record&.post
  end
end
