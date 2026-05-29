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
end
