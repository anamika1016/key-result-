module ApplicationHelper
  # Display user's name - prefer employee name if available, fallback to email
  def user_display_name(user)
    if user.employee_detail&.employee_name.present?
      user.employee_detail.employee_name
    else
      user.email
    end
  end

  # Return CSS classes for role badge styling
  def user_role_badge_class(role)
    case role
    when 'employee'
      'bg-blue-100 text-blue-800'
    when 'hod'
      'bg-purple-100 text-purple-800'
    when 'l1_employer'
      'bg-green-100 text-green-800'
    when 'l2_employer'
      'bg-orange-100 text-orange-800'
    else
      'bg-gray-100 text-gray-800'
    end
  end

  # Display human-readable role name
  def display_role_name(role)
    case role
    when 'employee'
      'Employee'
    when 'hod'
      'Head of Department'
    when 'l1_employer'
      'L1 Manager'
    when 'l2_employer'
      'L2 Manager'
    else
      role.humanize
    end
  end

  # Format date for display
  def format_date(date)
    return 'Not available' if date.blank?
    date.strftime('%B %d, %Y')
  end
end
