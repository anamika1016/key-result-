class HelpDeskTicketsController < ApplicationController
  before_action :load_help_desk_context
  before_action :set_assigned_ticket, only: :respond
  before_action :authorize_help_desk_response!, only: :respond
  before_action :set_requester_action_ticket, only: :finalize_resolution
  before_action :authorize_help_desk_finalization!, only: :finalize_resolution

  def index
    @help_desk_ticket = current_user.help_desk_tickets.new
  end

  def create
    @help_desk_ticket = build_help_desk_ticket

    if @help_desk_ticket.errors.any?
      render :index, status: :unprocessable_entity
    elsif @help_desk_ticket.save
      redirect_to help_desk_tickets_path, notice: "Your help desk request has been submitted successfully."
    else
      render :index, status: :unprocessable_entity
    end
  end

  def respond
    decision = review_decision_param
    selected_approval_user = approval_user_param unless decision == "keep_open"

    success =
      if decision != "keep_open" && params[:approval_user_id].present? && selected_approval_user.blank?
        @assigned_ticket.errors.add(:approval_user, "must be requester or original submitter")
        false
      else
        case decision
        when "keep_open"
          @assigned_ticket.keep_open_by(reviewer: current_user, response_message: response_message_param)
        when "send_for_approval", "close", "close_ticket"
          @assigned_ticket.mark_resolved_by(
            reviewer: current_user,
            response_message: response_message_param,
            approval_user: selected_approval_user,
            final_action_mode: "reopen_close"
          )
        else
          @assigned_ticket.errors.add(:base, "Choose whether you want to keep this ticket open or close it.")
          false
        end
      end

    if success
      notice =
        if decision == "keep_open"
          "Update shared successfully. The ticket is still open with support and can continue without any user action yet."
        else
          approval_name = @assigned_ticket.approval_pending_user&.display_name.presence || "the selected user"
          "Ticket marked as completed and shared with #{approval_name}. They can reopen it or close it within 24 hours."
        end

      redirect_to help_desk_tickets_path, notice: notice
    else
      @help_desk_ticket = current_user.help_desk_tickets.new
      @assigned_tickets = @assigned_tickets.map { |ticket| ticket.id == @assigned_ticket.id ? @assigned_ticket : ticket }
      render :index, status: :unprocessable_entity
    end
  end

  def finalize_resolution
    decision = requester_decision_param

    success =
      case decision
      when "reject", "reopen", "reverse"
        @requester_action_ticket.reject_by!(actor: current_user, remark: requester_remark_param)
      when "approve", "close"
        @requester_action_ticket.approve_by!(actor: current_user)
      else
        @requester_action_ticket.errors.add(:base, "Choose whether you want to reopen or close this ticket.")
        false
      end

    if success
      notice =
        if %w[reject reopen reverse].include?(decision)
          "Ticket reopened successfully and sent back to support with your remark."
        else
          "Ticket closed successfully."
        end
      redirect_to help_desk_tickets_path, notice: notice
    else
      @help_desk_ticket = current_user.help_desk_tickets.new
      @recent_tickets = @recent_tickets.map { |ticket| ticket.id == @requester_action_ticket.id ? @requester_action_ticket : ticket }
      render :index, status: :unprocessable_entity
    end
  end

  private

  def load_help_desk_context
    @requester_profile = current_user.mapped_employee_detail
    @departments = Department.selectable_verticals
    @can_review_help_desk_tickets = helpdesk_reviewer?
    @can_create_assisted_help_desk_tickets = @can_review_help_desk_tickets
    @help_desk_requester_options = build_help_desk_requester_options
    @help_desk_question_catalog = build_help_desk_question_catalog
    @recent_tickets = load_recent_tickets
    @assigned_tickets = load_assigned_tickets
  end

  def help_desk_ticket_params
    params.require(:help_desk_ticket).permit(:department_id, :request_type, :question_subject, :help_desk_question_master_id, :message, :requester_user_id, :on_behalf_requested, documents: [])
  end

  def response_message_param
    params.require(:help_desk_ticket).fetch(:response_message, "")
  end

  def review_decision_param
    params[:review_decision].to_s.presence || "close"
  end

  def requester_decision_param
    params[:decision].to_s
  end

  def requester_remark_param
    params.fetch(:help_desk_ticket, {}).fetch(:requester_remark, "")
  end

  def approval_user_param
    selected_id = params[:approval_user_id].to_s.presence
    return @assigned_ticket.approval_pending_user if selected_id.blank?

    @assigned_ticket.approval_candidate_users.find { |candidate| candidate.id == selected_id.to_i }
  end

  def load_assigned_tickets
    return HelpDeskTicket.none unless @can_review_help_desk_tickets

    scope = HelpDeskTicket.open_for_review
                          .includes(:department, :submitted_by_user, { user: :employee_detail }, { assigned_to_user: :employee_detail }, { approval_user: :employee_detail }, documents_attachments: :blob)
                          .recent_first

    current_user.hod? ? scope.limit(12) : scope.assigned_to(current_user).limit(12)
  end

  def load_recent_tickets
    includes_config = [
      :department,
      :submitted_by_user,
      { approval_user: :employee_detail },
      { assigned_to_user: :employee_detail },
      { responded_by_user: :employee_detail },
      { closed_by_user: :employee_detail },
      { user: :employee_detail },
      documents_attachments: :blob
    ]

    current_statuses = HelpDeskTicket::REVIEW_OPEN_STATUSES + ["resolved"]

    HelpDeskTicket.visible_to_actor(current_user)
                  .where(status: current_statuses)
                  .includes(*includes_config)
                  .recent_first
                  .limit(10)
                  .to_a
  end

  def set_assigned_ticket
    @assigned_ticket = HelpDeskTicket.includes(:department, :submitted_by_user, { user: :employee_detail }, { assigned_to_user: :employee_detail }, { responded_by_user: :employee_detail }, { approval_user: :employee_detail }, documents_attachments: :blob)
                                     .find(params[:id])
  end

  def set_requester_action_ticket
    @requester_action_ticket = HelpDeskTicket.includes(:department, :submitted_by_user, { user: :employee_detail }, { assigned_to_user: :employee_detail }, { responded_by_user: :employee_detail }, { closed_by_user: :employee_detail }, { approval_user: :employee_detail }, documents_attachments: :blob)
                                             .find(params[:id])
  end

  def authorize_help_desk_response!
    return if @assigned_ticket.can_be_responded_by?(current_user)

    redirect_to help_desk_tickets_path, alert: "You are not authorized to respond to this help desk request."
  end

  def authorize_help_desk_finalization!
    return if @requester_action_ticket.can_be_finalized_by?(current_user)

    redirect_to help_desk_tickets_path, alert: "You are not authorized to take action on this help desk ticket."
  end

  def build_help_desk_ticket
    ticket = current_user.help_desk_tickets.new(help_desk_ticket_params)
    ticket.submitted_by_user = current_user

    assisted_requested = ActiveModel::Type::Boolean.new.cast(ticket.on_behalf_requested)
    return ticket unless assisted_requested

    unless can_create_assisted_help_desk_tickets?
      ticket.errors.add(:base, "Only help desk reviewers can raise tickets on behalf of another employee.")
      return ticket
    end

    requester_user = User.find_by(id: ticket.requester_user_id)
    if requester_user.blank?
      ticket.errors.add(:requester_user_id, "Please select the employee for whom you are raising this ticket.")
      return ticket
    end

    if requester_user == current_user
      ticket.errors.add(:requester_user_id, "Choose another employee or turn off on behalf mode.")
      return ticket
    end

    ticket.user = requester_user
    ticket.raised_on_behalf = true if ticket.has_attribute?(:raised_on_behalf)
    ticket
  end

  def build_help_desk_requester_options
    User.includes(:employee_detail)
        .where.not(id: current_user.id)
        .map do |user|
          identifier = user.employee_code.presence || user.email
          [ "#{user.display_name} (#{identifier})", user.id ]
        end
        .sort_by(&:first)
  end

  def can_create_assisted_help_desk_tickets?
    @can_create_assisted_help_desk_tickets
  end

  def build_help_desk_question_catalog
    HelpDeskQuestionMaster.active
                          .order(:department_id, :request_type, :position, :created_at)
                          .map do |question|
      {
        id: question.id,
        department_id: question.department_id,
        request_type: question.request_type,
        question_text: question.question_text
      }
    end
  end
end
