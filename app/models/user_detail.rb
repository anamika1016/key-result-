class UserDetail < ApplicationRecord
  belongs_to :department
  belongs_to :activity
  belongs_to :employee_detail, optional: true, counter_cache: :user_details_count  # optional if it can be nil
  has_many :achievements, dependent: :destroy

  # Validation to prevent duplicate records
  validates :department_id, uniqueness: { scope: [ :activity_id, :employee_detail_id ],
                                         message: "A record already exists for this department, activity, and employee combination" }

  # Delegate useful methods
  delegate :employee_name, :employee_code, :employee_email, to: :employee_detail, allow_nil: true
  delegate :department_type, to: :department, allow_nil: true
  delegate :activity_name, :theme_name, :weight, :unit, to: :activity, allow_nil: true

  # Get department-specific L1/L2 for this user detail
  def l1_info
    employee_detail&.l1_for_department(department_id) || {}
  end

  def l2_info
    employee_detail&.l2_for_department(department_id) || {}
  end

  # Scopes for filtering
  scope :for_employee, ->(employee_code) {
    joins(:employee_detail).where(employee_details: { employee_code: employee_code })
  }

  scope :for_department, ->(dept_id) { where(department_id: dept_id) }

  scope :for_department_type, ->(dept_type) {
    joins(:department).where(departments: { department_type: dept_type })
  }

  # Check if this user detail belongs to specific L1/L2
  def belongs_to_l1?(user_code_or_email)
    l1_info = self.l1_info
    l1_info[:code] == user_code_or_email || l1_info[:name] == user_code_or_email
  end

  def belongs_to_l2?(user_code_or_email)
    l2_info = self.l2_info
    l2_info[:code] == user_code_or_email || l2_info[:name] == user_code_or_email
  end
end
