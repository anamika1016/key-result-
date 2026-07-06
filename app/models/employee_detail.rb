class EmployeeDetail < ApplicationRecord
  has_many :user_details, dependent: :destroy
  has_many :sms_logs, dependent: :destroy
  has_many :quiz_submissions, dependent: :nullify
  belongs_to :user, optional: true
  has_many :user_training_assignments, dependent: :destroy
  has_many :assigned_trainings, through: :user_training_assignments, source: :training
  before_validation :normalize_employee_code
  after_initialize :set_default_status, if: :new_record?
  after_create :create_user_account

  validates :employee_code, uniqueness: { case_sensitive: false }, allow_blank: true

  # Support for multiple departments through user_details
  has_many :departments, through: :user_details
  has_many :activities, through: :user_details

  # Mobile number validation removed as requested

  def name
    employee_name
  end

  # Get all departments this employee belongs to
  def employee_departments
    departments.distinct
  end

  # Get L1 and L2 for specific department (override default if needed)
  def l1_for_department(department_id)
    # For now, use the default L1 from employee_details
    # In future, this can be overridden per department
    {
      code: l1_code,
      name: l1_employer_name
    }
  end

  def l2_for_department(department_id)
    # For now, use the default L2 from employee_details
    # In future, this can be overridden per department
    {
      code: l2_code,
      name: l2_employer_name
    }
  end

  def l3_for_department(department_id)
    # For now, use the default L3 from employee_details
    # In future, this can be overridden per department
    {
      code: l3_code,
      name: l3_employer_name
    }
  end

  # Check if employee belongs to specific department
  def belongs_to_department?(department_id)
    user_details.joins(:department).where(departments: { id: department_id }).exists?
  end

  # Get all activities for a specific department
  def activities_for_department(department_id)
    user_details.includes(:activity)
                .joins(:department)
                .where(departments: { id: department_id })
                .map(&:activity)
                .compact
                .uniq
  end

  def self.ransackable_attributes(auth_object = nil)
    %w[
      employee_name
      employee_email
      employee_code
      mobile_number
      office_type
      office_name
      l1_code
      l1_employer_name
      l2_code
      l2_employer_name
      l3_code
      l3_employer_name
      post
      position
      department
      created_at
      updated_at
    ]
  end


  enum :status, {
  pending: "pending",
  l1_approved: "l1_approved",
  l1_rejected: "l1_returned",
  l2_approved: "l2_approved",
  l2_returned: "l2_returned",
  l3_approved: "l3_approved",
  l3_returned: "l3_returned",
  returned_to_employee: "returned_to_employee"
}

# Performance optimized scopes
scope :l1_pending_records, -> { where(status: [ "pending", "returned" ]) }
scope :l3_pending_records, -> { where(status: [ "l2_approved" ]) }

# Scopes for L1, L2, L3 filtering with includes
scope :for_l1_user, ->(user_or_value) {
  values = manager_lookup_values(user_or_value)
  where("TRIM(l1_code) IN (:values) OR LOWER(REGEXP_REPLACE(TRIM(l1_employer_name), '\\s+', ' ', 'g')) IN (:normalized_values)",
        values: values,
        normalized_values: values.map(&:downcase))
  .includes(user_details: [ :department, :activity, achievements: :achievement_remark ])
}

scope :for_l2_user, ->(user_or_value) {
  values = manager_lookup_values(user_or_value)
  where("TRIM(l2_code) IN (:values) OR LOWER(REGEXP_REPLACE(TRIM(l2_employer_name), '\\s+', ' ', 'g')) IN (:normalized_values)",
        values: values,
        normalized_values: values.map(&:downcase))
  .includes(user_details: [ :department, :activity, achievements: :achievement_remark ])
}

scope :for_l3_user, ->(user_or_value) {
  values = manager_lookup_values(user_or_value)
  where("TRIM(l3_code) IN (:values) OR LOWER(REGEXP_REPLACE(TRIM(l3_employer_name), '\\s+', ' ', 'g')) IN (:normalized_values)",
        values: values,
        normalized_values: values.map(&:downcase))
  .includes(user_details: [ :department, :activity, achievements: :achievement_remark ])
}

scope :with_l1_approved_achievements, -> {
  joins(user_details: :achievements)
  .where(achievements: { status: [ "l1_approved", "l2_approved", "l2_returned" ] })
  .distinct
}

scope :with_l2_approved_achievements, -> {
  joins(user_details: :achievements)
  .where(achievements: { status: "l2_approved" })
  .distinct
}



  # ✅ Allow only safe associations (empty if none)
  def self.ransackable_associations(auth_object = nil)
    []
  end

  def self.manager_lookup_values(user_or_value)
    values = if user_or_value.respond_to?(:employee_code)
      [
        user_or_value.employee_code,
        user_or_value.email,
        user_or_value.try(:display_name),
        user_or_value.try(:mapped_employee_detail)&.employee_name
      ]
    else
      [ user_or_value ]
    end

    values.compact.map { |value| value.to_s.squish }.reject(&:blank?).uniq
  end

  def set_default_status
   self.status ||= "pending"
  end

  private

  def normalize_employee_code
    self.employee_code = employee_code.to_s.strip.presence
  end

  def create_user_account
    # Only create user account if we have required data
    return unless employee_email.present? && employee_code.present?

    # Check if user already exists
    existing_user = User.find_by(email: employee_email) || User.find_by(employee_code: employee_code)
    if existing_user
      existing_user.update(employee_code: employee_code) if existing_user.employee_code.to_s.strip != employee_code.to_s.strip
      update_column(:user_id, existing_user.id) if user_id.blank?
      return
    end

    begin
      # Create user account with default password and role
      user = User.create!(
        email: employee_email,
        employee_code: employee_code,
        password: "123456",
        password_confirmation: "123456",
        role: "employee"
      )

      Rails.logger.info "Created user account for employee: #{employee_name} (#{employee_code})"
    rescue => e
      Rails.logger.error "Failed to create user account for employee #{employee_name}: #{e.message}"
    end
  end
end
