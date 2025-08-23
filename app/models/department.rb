  # class Department < ApplicationRecord
  #   has_many :activities, dependent: :destroy
  #   has_many :user_details
    
  #   accepts_nested_attributes_for :activities, allow_destroy: true, reject_if: :all_blank
  # end


  
  class Department < ApplicationRecord
  has_many :activities, dependent: :destroy
  has_many :user_details
  
  accepts_nested_attributes_for :activities, allow_destroy: true, reject_if: :all_blank

  validates :department_type, presence: true
  # validates :employee_reference, presence: true

  # Get employee name from employee_reference (which stores employee_id)
  def employee_name
    employee = EmployeeDetail.find_by(employee_id: self.employee_reference)
    employee&.employee_name || 'N/A'
  end

  # Get employee details
  def employee_detail
    EmployeeDetail.find_by(employee_id: self.employee_reference)
  end

  # Get employee code
  def employee_code
    employee = EmployeeDetail.find_by(employee_id: self.employee_reference)
    employee&.employee_code || 'N/A'
  end

  # Get full employee display name with code
  def employee_display_name
    employee = EmployeeDetail.find_by(employee_id: self.employee_reference)
    if employee
      "#{employee.employee_name} (#{employee.employee_code})"
    else
      'N/A'
    end
  end
end