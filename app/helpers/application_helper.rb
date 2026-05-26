module ApplicationHelper
  # Display user's name - prefer employee name if available, fallback to email
  def user_display_name(user)
    user.display_name
  end

  # Return CSS classes for role badge styling
  def user_role_badge_class(role)
    case role
    when "employee"
      "bg-blue-100 text-blue-800"
    when "hod"
      "bg-purple-100 text-purple-800"
    when "l1_employer"
      "bg-green-100 text-green-800"
    when "l2_employer"
      "bg-orange-100 text-orange-800"
    else
      "bg-gray-100 text-gray-800"
    end
  end

  # Display human-readable role name
  def display_role_name(role)
    case role
    when "employee"
      "Employee"
    when "hod"
      "Head of Department"
    when "l1_employer"
      "L1 Manager"
    when "l2_employer"
      "L2 Manager"
    else
      role.humanize
    end
  end

  # Format date for display
  def format_date(date)
    return "Not available" if date.blank?
    date.strftime("%B %d, %Y")
  end

  def help_desk_status_badge_class(ticket)
    case ticket.status
    when "submitted"
      "border-emerald-200 bg-emerald-50 text-emerald-700"
    when "in_review", "reopened"
      "border-amber-200 bg-amber-50 text-amber-700"
    when "resolved"
      "border-indigo-200 bg-indigo-50 text-indigo-700"
    when "closed"
      "border-slate-300 bg-slate-100 text-slate-700"
    else
      "border-slate-200 bg-slate-50 text-slate-600"
    end
  end

  def help_desk_status_label(ticket)
    case ticket.status
    when "in_review"
      "Open With Support"
    when "resolved"
      ticket.final_action_mode_approve_reject? ? "Pending Approve / Reject" : "Pending Reopen / Close"
    when "reopened"
      "Reopened By User"
    else
      ticket.status.to_s.humanize
    end
  end

  def help_desk_status_badge_tone(ticket)
    case ticket.status
    when "submitted"
      "helpdesk-badge--success"
    when "in_review", "reopened"
      "helpdesk-badge--warning"
    when "resolved"
      "helpdesk-badge--info"
    else
      "helpdesk-badge--neutral"
    end
  end

  def help_desk_format_text(text)
    url_pattern = %r{(https?://[^\s<]+)}
    linked_text = safe_join(text.to_s.split(url_pattern).map do |part|
      if part.match?(/\Ahttps?:\/\//)
        link_to(part, part, target: "_blank", rel: "noopener", class: "helpdesk-inline-link")
      else
        h(part)
      end
    end)

    simple_format(linked_text, {}, sanitize: false)
  end

  def help_desk_menu_notification_count
    help_desk_user_action_count + help_desk_assigned_count
  end

  def help_desk_user_action_count
    return 0 unless current_user.present?

    @help_desk_user_action_count ||= HelpDeskTicket.pending_user_action_for(current_user).count
  end

  def help_desk_assigned_count
    return 0 unless current_user.present? && helpdesk_reviewer?

    @help_desk_assigned_count ||= HelpDeskTicket.open_for_review.where(assigned_to_user_id: current_user.id).count
  end

  def help_desk_notification_label(count)
    count > 99 ? "99+" : count.to_s
  end

  def help_desk_menu_notification_label
    help_desk_notification_label(help_desk_menu_notification_count)
  end
end
