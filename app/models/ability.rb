
# class Ability
#   include CanCan::Ability

#   def initialize(user)
#     return unless user.present?

#     if user.hod?
#       can :manage, :all  # Admin gets full access to all models
#     elsif user.employee?
#       can :read, EmployeeDetail, employee_email: user.email
#     elsif user.l1_employer?
#       can :read, EmployeeDetail do |ed|
#         ['pending', 'l1_returned', 'l1_approved', 'l2_returned', 'l2_approved'].include?(ed.status) &&
#         ed.l1_code == user.employee_code
#       end

#       can [:approve, :return], EmployeeDetail do |ed|
#         ['pending', 'l1_returned'].include?(ed.status) &&
#         ed.l1_code == user.employee_code
#       end

#       can :l1, EmployeeDetail  # allow access to `l1` custom action

#     elsif user.l2_employer?
#       # L2 can read records only if they're in these states
#       can :read, EmployeeDetail do |ed|
#         ['l1_approved', 'l2_returned', 'l2_approved'].include?(ed.status) &&
#         (ed.l2_code == user.employee_code || ed.l2_employer_name == user.email)
#       end

#       # Updated show_l2 permission - more flexible
#       can :show_l2, EmployeeDetail do |ed|
#         # Allow if user is L2 employer and has any of these statuses
#         user.l2_employer? && 
#         (ed.l2_code == user.employee_code || ed.l2_employer_name == user.email)
#       end

#       can [:l2_approve, :l2_return], EmployeeDetail do |ed|
#         ['l1_approved', 'l2_returned'].include?(ed.status) &&
#         (ed.l2_code == user.employee_code || ed.l2_employer_name == user.email)
#       end

#       can :l2, EmployeeDetail
#     end

#     # Add HOD permissions for L2 actions as well
#     if user.hod?
#       can :show_l2, EmployeeDetail
#       can [:l2_approve, :l2_return], EmployeeDetail
#       can :l2, EmployeeDetail
#     end

#   end
# end

class Ability
  include CanCan::Ability

  def initialize(user)
    return unless user.present?

    if user.hod?
      can :manage, :all  # HOD gets full access to all models
    end

    # Employee permissions (everyone should have these basic permissions)
    if user.employee? || user.l1_employer? || user.l2_employer?
      can :read, EmployeeDetail, employee_email: user.email
    end

    # L1 Employer permissions - Check if user has any L1 assignments
    l1_employee_details = EmployeeDetail.where(l1_code: user.employee_code)
    if user.l1_employer? || l1_employee_details.exists?
      can :read, EmployeeDetail do |ed|
        ['pending', 'l1_returned', 'l1_approved', 'l2_returned', 'l2_approved'].include?(ed.status) &&
        ed.l1_code == user.employee_code
      end

      can [:approve, :return], EmployeeDetail do |ed|
        ['pending', 'l1_returned'].include?(ed.status) &&
        ed.l1_code == user.employee_code
      end

      can :l1, EmployeeDetail  # allow access to `l1` custom action
    end

    # L2 Employer permissions - Check if user has any L2 assignments  
    l2_employee_details = EmployeeDetail.where(
      "l2_code = ? OR l2_employer_name = ?", 
      user.employee_code, 
      user.email
    )
    
    if user.l2_employer? || l2_employee_details.exists?
      # L2 can read records only if they're in these states
      can :read, EmployeeDetail do |ed|
        ['l1_approved', 'l2_returned', 'l2_approved'].include?(ed.status) &&
        (ed.l2_code == user.employee_code || ed.l2_employer_name == user.email)
      end

      # Show L2 permission
      can :show_l2, EmployeeDetail do |ed|
        (ed.l2_code == user.employee_code || ed.l2_employer_name == user.email)
      end

      can [:l2_approve, :l2_return], EmployeeDetail do |ed|
        ['l1_approved', 'l2_returned'].include?(ed.status) &&
        (ed.l2_code == user.employee_code || ed.l2_employer_name == user.email)
      end

      can :l2, EmployeeDetail
    end

    # Add HOD permissions for L2 actions as well
    if user.hod?
      can :show_l2, EmployeeDetail
      can [:l2_approve, :l2_return], EmployeeDetail
      can :l2, EmployeeDetail
    end
  end
end