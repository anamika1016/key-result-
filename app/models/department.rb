# class Department < ApplicationRecord
#   has_many :activities, dependent: :destroy
#   has_many :user_details

#   accepts_nested_attributes_for :activities, allow_destroy: true, reject_if: :all_blank
# end



class Department < ApplicationRecord
has_many :activities, dependent: :destroy
has_many :user_details, dependent: :destroy
has_many :help_desk_tickets
has_many :help_desk_question_masters, dependent: :destroy
has_one :helpdesk_escalation_matrix, dependent: :destroy
# Support for multiple employees through user_details
has_many :employee_details, through: :user_details

accepts_nested_attributes_for :activities, allow_destroy: true, reject_if: :all_blank

validates :department_type, presence: true
  # Callback methods for global user detail sync have been removed to prevent cross-assignment.

  def self.selectable_verticals
    department_names = (
      distinct.pluck(:department_type) +
      EmployeeDetail.distinct.pluck(:department)
    ).map { |name| name.to_s.strip }
     .reject(&:blank?)
     .uniq

    existing_departments = where(department_type: department_names).index_by(&:department_type)
    missing_department_names = department_names - existing_departments.keys

    missing_department_names.each do |department_name|
      existing_departments[department_name] = create!(department_type: department_name)
    end

    existing_departments.values.sort_by { |department| [ department.department_type.to_s.downcase, department.theme_name.to_s.downcase ] }
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
