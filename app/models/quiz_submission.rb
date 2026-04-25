class QuizSubmission < ApplicationRecord
  belongs_to :quiz
  belongs_to :user_quiz
  belongs_to :user, optional: true
  belongs_to :employee_detail, optional: true

  validates :employee_code, :name, :status, :submitted_at, presence: true
  validates :employee_code, uniqueness: { scope: :quiz_id, case_sensitive: false }

  before_validation :normalize_fields
  before_validation :copy_profile_details, if: :user_quiz

  scope :recent_first, -> { order(submitted_at: :desc, id: :desc) }

  private

  def normalize_fields
    self.employee_code = employee_code.to_s.strip.presence
    self.name = name.to_s.strip.presence
    self.email = email.to_s.strip.downcase.presence
    self.mobile_number = mobile_number.to_s.strip.presence
    self.designation = designation.to_s.strip.presence
    self.branch = branch.to_s.strip.presence
    self.sub_branch = sub_branch.to_s.strip.presence
    self.status = status.to_s.strip.presence
  end

  def copy_profile_details
    self.user ||= user_quiz.user
    self.employee_detail ||= user_quiz.employee_detail_record
    self.employee_code ||= user_quiz.employee_code
    self.name ||= user_quiz.display_name
    self.email ||= user_quiz.email
    self.mobile_number ||= user_quiz.mobile_number
    self.designation ||= user_quiz.display_designation
    self.branch ||= user_quiz.branch
    self.sub_branch ||= user_quiz.sub_branch
  end
end
