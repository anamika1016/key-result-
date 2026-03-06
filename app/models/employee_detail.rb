class EmployeeDetail < ApplicationRecord
  has_many :user_details, dependent: :destroy
  has_many :sms_logs, dependent: :destroy
  belongs_to :user, optional: true
  after_initialize :set_default_status, if: :new_record?
  after_create :create_user_account

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
      l1_code
      l1_employer_name
      l2_code
      l2_employer_name
      l3_code
      l3_employer_name
      post
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
scope :for_l1_user, ->(employee_code_or_email) {
  where("TRIM(l1_code) = ? OR l1_employer_name = ?", employee_code_or_email.strip, employee_code_or_email)
  .includes(user_details: [ :department, :activity, achievements: :achievement_remark ])
}

scope :for_l2_user, ->(employee_code) {
  where("TRIM(l2_code) = ? OR l2_employer_name = ?", employee_code.strip, employee_code)
  .includes(user_details: [ :department, :activity, achievements: :achievement_remark ])
}

scope :for_l3_user, ->(employee_code) {
  where("TRIM(l3_code) = ? OR l3_employer_name = ?", employee_code.strip, employee_code)
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

  def set_default_status
   self.status ||= "pending"
  end

  private

  def create_user_account
    # Only create user account if we have required data
    return unless employee_email.present? && employee_code.present?

    # Check if user already exists
    existing_user = User.find_by(email: employee_email) || User.find_by(employee_code: employee_code)
    return if existing_user

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
