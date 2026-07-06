class Ability
  include CanCan::Ability

  def initialize(user)
    return unless user.present?

    if user.hod?
      can :manage, :all  # HOD gets full access to all models
      return  # Early return for HOD to avoid duplicate permissions
    end

    # UserDetail permissions for employees
    if user.employee? || user.l1_employer? || user.l2_employer?
      can :read, UserDetail do |ud|
        # Users can read their own user details
        ud.employee_detail&.employee_email == user.email ||
        ud.employee_detail&.employee_code == user.employee_code
      end

      can [ :edit, :update, :destroy ], UserDetail do |ud|
        # Users can edit/delete their own user details
        ud.employee_detail&.employee_email == user.email ||
        ud.employee_detail&.employee_code == user.employee_code
      end
    end

    # Basic employee permissions
    if user.employee? || user.l1_employer? || user.l2_employer?
      can :create, HelpDeskTicket
      can :read, HelpDeskTicket, user_id: user.id
      can [ :read, :respond ], HelpDeskTicket, assigned_to_user_id: user.id
      can :read, EmployeeDetail, employee_email: user.email
      can :read, EmployeeDetail, employee_code: user.employee_code
    end

    # L1 Permissions - Check if user's employee_code matches any l1_code OR email matches l1_employer_name
    # Allow reading regardless of status - status restrictions only apply to approve/return actions
    can :read, EmployeeDetail do |ed|
      manager_matches?(ed.l1_code, ed.l1_employer_name, user)
    end

    can [ :approve, :return ], EmployeeDetail do |ed|
      manager_matches?(ed.l1_code, ed.l1_employer_name, user) &&
      [ "pending", "l1_returned" ].include?(ed.status)
    end

    can :l1, EmployeeDetail do
      # User can access L1 view if they have any L1 assignments
      EmployeeDetail.for_l1_user(user).exists?
    end

    # L2 Permissions - Check if user's employee_code matches any l2_code OR email matches l2_employer_name
    # Allow reading regardless of status - status restrictions only apply to approve/return actions
    can :read, EmployeeDetail do |ed|
      manager_matches?(ed.l2_code, ed.l2_employer_name, user)
    end

    can :show_l2, EmployeeDetail do |ed|
      manager_matches?(ed.l2_code, ed.l2_employer_name, user)
    end

    can [ :l2_approve, :l2_return ], EmployeeDetail do |ed|
      manager_matches?(ed.l2_code, ed.l2_employer_name, user) &&
      [ "l1_approved", "l2_returned" ].include?(ed.status)
    end

    can :l2, EmployeeDetail do
      # User can access L2 view if they have any L2 assignments
      EmployeeDetail.for_l2_user(user).exists?
    end

    # L3 Permissions - Check if user's employee_code matches any l3_code OR email matches l3_employer_name
    # Allow reading regardless of status - status restrictions only apply to approve/return actions
    can :read, EmployeeDetail do |ed|
      manager_matches?(ed.l3_code, ed.l3_employer_name, user)
    end

    can :show_l3, EmployeeDetail do |ed|
      manager_matches?(ed.l3_code, ed.l3_employer_name, user)
    end

    can [ :l3_approve, :l3_return ], EmployeeDetail do |ed|
      manager_matches?(ed.l3_code, ed.l3_employer_name, user) &&
      [ "l2_approved", "l3_returned" ].include?(ed.status)
    end

    can :l3, EmployeeDetail do
      # User can access L3 view if they have any L3 assignments
      EmployeeDetail.for_l3_user(user).exists?
    end
  end

  private

  def manager_matches?(manager_code, manager_name_or_email, user)
    lookup_values = EmployeeDetail.manager_lookup_values(user)
    normalized_lookup_values = lookup_values.map(&:downcase)

    lookup_values.include?(manager_code.to_s.strip) ||
      normalized_lookup_values.include?(manager_name_or_email.to_s.squish.downcase)
  end
end
