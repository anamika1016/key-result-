# class Department < ApplicationRecord
#   has_many :activities, dependent: :destroy
#   has_many :user_details

#   accepts_nested_attributes_for :activities, allow_destroy: true, reject_if: :all_blank
# end



class Department < ApplicationRecord
has_many :activities, dependent: :destroy
has_many :user_details, dependent: :destroy
# Support for multiple employees through user_details
has_many :employee_details, through: :user_details

accepts_nested_attributes_for :activities, allow_destroy: true, reject_if: :all_blank

validates :department_type, presence: true
# validates :employee_reference, presence: true

# Callback to create UserDetail records when activities are created
after_save :create_user_details_for_activities

# Callback to handle activity updates and deletions
after_update :sync_user_details_with_activities

# Get all employees in this department
def employees
  employee_details.distinct
end

# Get employees with their department-specific L1/L2 info
def employees_with_l1_l2
  employees.map do |employee|
    {
      employee: employee,
      l1: employee.l1_for_department(id),
      l2: employee.l2_for_department(id),
      activities_count: employee.activities_for_department(id).count
    }
  end
end

# Check if an employee belongs to this department
def has_employee?(employee_code)
  user_details.joins(:employee_detail)
              .where(employee_details: { employee_code: employee_code })
              .exists?
end

# Add employee to department (create UserDetail records for all activities)
def add_employee(employee_code)
  employee = EmployeeDetail.find_by(employee_code: employee_code)
  return false unless employee

  activities.each do |activity|
    unless UserDetail.exists?(
      department_id: id,
      activity_id: activity.id,
      employee_detail_id: employee.id
    )
      UserDetail.create!(
        department_id: id,
        activity_id: activity.id,
        employee_detail_id: employee.id
      )
    end
  end
  true
end

# Remove employee from department
def remove_employee(employee_code)
  employee = EmployeeDetail.find_by(employee_code: employee_code)
  return false unless employee

  user_details.where(employee_detail_id: employee.id).destroy_all
  true
end

# Class method to assign an employee to multiple departments
def self.assign_employee_to_departments(employee_code, department_ids)
  employee = EmployeeDetail.find_by(employee_code: employee_code)
  return false unless employee

  department_ids.each do |dept_id|
    department = Department.find_by(id: dept_id)
    next unless department

    department.add_employee(employee_code)
  end
  true
end

# Class method to get all employees with their multiple department assignments
def self.employees_with_multiple_departments
  EmployeeDetail.joins(user_details: :department)
                .group("employee_details.id, employee_details.employee_code, employee_details.employee_name")
                .having("COUNT(DISTINCT departments.id) > 1")
                .select("employee_details.*, COUNT(DISTINCT departments.id) as department_count")
end

  private

  def create_user_details_for_activities
    return unless employee_reference.present?

    # Find the employee
    employee = EmployeeDetail.find_by(employee_code: employee_reference)
    return unless employee

    # Create UserDetail records for each activity
    activities.each do |activity|
      # Check if UserDetail already exists to avoid duplicates
      existing_user_detail = UserDetail.find_by(
        department_id: id,
        activity_id: activity.id,
        employee_detail_id: employee.id
      )

      unless existing_user_detail
        UserDetail.create!(
          department_id: id,
          activity_id: activity.id,
          employee_detail_id: employee.id
        )
      end
    end
  end

  def sync_user_details_with_activities
    return unless employee_reference.present?

    # Find the employee
    employee = EmployeeDetail.find_by(employee_code: employee_reference)
    return unless employee

    # Get current activity IDs
    current_activity_ids = activities.pluck(:id)

    # Remove UserDetail records for activities that no longer exist
    UserDetail.where(
      department_id: id,
      employee_detail_id: employee.id
    ).where.not(activity_id: current_activity_ids).destroy_all

    # Create UserDetail records for new activities
    current_activity_ids.each do |activity_id|
      existing_user_detail = UserDetail.find_by(
        department_id: id,
        activity_id: activity_id,
        employee_detail_id: employee.id
      )

      unless existing_user_detail
        UserDetail.create!(
          department_id: id,
          activity_id: activity_id,
          employee_detail_id: employee.id
        )
      end
    end
  end

  # Get employee name from employee_reference (which stores employee_id)
  def employee_name
    employee = EmployeeDetail.find_by(employee_code: self.employee_reference)
    employee&.employee_name || "N/A"
  end

  # Get employee details
  def employee_detail
    EmployeeDetail.find_by(employee_code: self.employee_reference)
  end

  # Get employee code
  def employee_code
    employee = EmployeeDetail.find_by(employee_code: self.employee_reference)
    employee&.employee_code || "N/A"
  end

  # Get full employee display name with code
  def employee_display_name
    employee = EmployeeDetail.find_by(employee_code: self.employee_reference)
    if employee
      "#{employee.employee_name} (#{employee.employee_code})"
    else
      "N/A"
    end
  end
end
