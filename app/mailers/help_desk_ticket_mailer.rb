class HelpDeskTicketMailer < ApplicationMailer
  def ticket_assigned(ticket_id)
    @ticket = HelpDeskTicket.includes(:department, :user, :submitted_by_user, :assigned_to_user).find(ticket_id)
    @assignee = @ticket.assigned_to_user

    mail(
      to: @assignee.email,
      subject: "Help Desk Ticket Assigned - #{@ticket.department.department_type}"
    )
  end

  def ticket_resolved(ticket_id, recipients)
    @ticket = HelpDeskTicket.includes(:department, :user, :submitted_by_user, :responded_by_user).find(ticket_id)
    @recipients = Array(recipients).compact

    mail(
      to: @recipients,
      subject: "Help Desk Ticket Resolved - #{@ticket.department.department_type}"
    )
  end

  def ticket_updated(ticket_id, recipients)
    @ticket = HelpDeskTicket.includes(:department, :user, :submitted_by_user, :assigned_to_user, :responded_by_user).find(ticket_id)
    @recipients = Array(recipients).compact

    mail(
      to: @recipients,
      subject: "Help Desk Ticket Update - #{@ticket.ticket_reference}"
    )
  end

  def ticket_action(ticket_id, recipients, action_label)
    @ticket = HelpDeskTicket.includes(:department, :user, :submitted_by_user, :assigned_to_user, :responded_by_user, :closed_by_user, :approval_user).find(ticket_id)
    @recipients = Array(recipients).compact
    @action_label = action_label.to_s.presence || "Updated"

    mail(
      to: @recipients,
      subject: "Help Desk #{@action_label} - #{@ticket.ticket_reference}"
    )
  end
end
