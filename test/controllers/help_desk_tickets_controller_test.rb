require "test_helper"

class HelpDeskTicketsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @department = Department.create!(
      department_type: "Administration",
      theme_id: 202,
      theme_name: "Support"
    )

    @user = User.create!(
      email: "support.user@example.com",
      employee_code: "EMP901",
      password: "password123",
      password_confirmation: "password123",
      role: "employee"
    )

    @l1_user = User.create!(
      email: "helpdesk.l1@example.com",
      employee_code: "L1002",
      password: "password123",
      password_confirmation: "password123",
      role: "employee"
    )

    @l2_user = User.create!(
      email: "helpdesk.l2@example.com",
      employee_code: "L2002",
      password: "password123",
      password_confirmation: "password123",
      role: "employee"
    )

    @l3_user = User.create!(
      email: "helpdesk.l3@example.com",
      employee_code: "L3002",
      password: "password123",
      password_confirmation: "password123",
      role: "hod"
    )

    @submitter_user = User.create!(
      email: "helpdesk.submitter@example.com",
      employee_code: "SUB902",
      password: "password123",
      password_confirmation: "password123",
      role: "employee"
    )

    EmployeeDetail.create!(
      user: @user,
      employee_name: "Support User",
      employee_email: @user.email,
      employee_code: @user.employee_code,
      department: "Administration"
    )

    HelpdeskEscalationMatrix.create!(
      department: @department,
      escalation_levels_attributes: [
        { position: 1, user_id: @l1_user.id },
        { position: 2, user_id: @l2_user.id },
        { position: 3, user_id: @l3_user.id }
      ]
    )

    @question_master = HelpDeskQuestionMaster.create!(
      department: @department,
      request_type: "complaint",
      question_text: "System login issue",
      position: 1
    )
  end

  test "should get index for signed in user" do
    sign_in @user

    get help_desk_tickets_url

    assert_response :success
    assert_select "h1", "Help Desk"
  end

  test "should create help desk ticket and assign first escalation" do
    sign_in @user

    assert_difference("HelpDeskTicket.count", 1) do
      post help_desk_tickets_url, params: {
        help_desk_ticket: {
          department_id: @department.id,
          request_type: "complaint",
          help_desk_question_master_id: @question_master.id,
          message: "My system login is not syncing with the support queue."
        }
      }
    end

    ticket = HelpDeskTicket.order(:id).last

    assert_redirected_to help_desk_tickets_url
    assert_equal @l1_user.id, ticket.assigned_to_user_id
    assert_equal 1, ticket.current_escalation_position
    assert_equal "System login issue", ticket.question_subject
  end

  test "assigned approver can keep ticket open with a support update" do
    ticket = HelpDeskTicket.create!(
      user: @user,
      department: @department,
      request_type: "suggestion",
      question_subject: "Queue status clarity",
      message: "Please make the queue status clearer."
    )

    sign_in @l1_user

    patch respond_help_desk_ticket_url(ticket), params: {
      review_decision: "keep_open",
      help_desk_ticket: {
        response_message: "Work is still in progress and we are checking the queue behavior."
      }
    }

    assert_redirected_to help_desk_tickets_url

    ticket.reload
    assert_equal "in_review", ticket.status
    assert_equal @l1_user.id, ticket.responded_by_user_id
    assert_equal @l1_user.id, ticket.assigned_to_user_id
    assert_nil ticket.requester_response_due_at
    assert_equal "Work is still in progress and we are checking the queue behavior.", ticket.response_message
  end

  test "sidebar shows help desk badge count for assigned reviewer tickets" do
    HelpDeskTicket.create!(
      user: @user,
      department: @department,
      request_type: "complaint",
      question_subject: "Network issue",
      message: "There is a fresh network issue for reviewer notification."
    )

    sign_in @l1_user

    get help_desk_tickets_url

    assert_response :success
    assert_includes response.body, 'data-helpdesk-menu-badge="1"'
  end

  test "assigned approver can close ticket from support side" do
    ticket = HelpDeskTicket.create!(
      user: @user,
      department: @department,
      request_type: "suggestion",
      question_subject: "Queue status clarity",
      message: "Please make the queue status clearer."
    )

    sign_in @l1_user

    patch respond_help_desk_ticket_url(ticket), params: {
      review_decision: "close",
      approval_user_id: @user.id,
      help_desk_ticket: {
        response_message: "Issue reviewed and action has been completed."
      }
    }

    assert_redirected_to help_desk_tickets_url

    ticket.reload
    assert_equal "resolved", ticket.status
    assert_equal @l1_user.id, ticket.responded_by_user_id
    assert_equal @user.id, ticket.approval_user_id
    assert_equal "reopen_close", ticket.final_action_mode
    assert_equal "Issue reviewed and action has been completed.", ticket.response_message
  end

  test "assigned approver can close ticket from support side and send reopen close action" do
    ticket = HelpDeskTicket.create!(
      user: @user,
      department: @department,
      request_type: "complaint",
      question_subject: "Internet issue",
      message: "The internet issue needs a support closure flow."
    )

    sign_in @l1_user

    patch respond_help_desk_ticket_url(ticket), params: {
      review_decision: "close",
      approval_user_id: @user.id,
      help_desk_ticket: {
        response_message: "Internet issue has been fixed from support side."
      }
    }

    assert_redirected_to help_desk_tickets_url

    ticket.reload
    assert_equal "resolved", ticket.status
    assert_equal @user.id, ticket.approval_user_id
    assert_equal "reopen_close", ticket.final_action_mode
  end

  test "assigned approver cannot choose an unrelated action user" do
    ticket = HelpDeskTicket.create!(
      user: @user,
      department: @department,
      request_type: "suggestion",
      question_subject: "Queue status clarity",
      message: "Please make the queue status clearer."
    )

    sign_in @l1_user

    patch respond_help_desk_ticket_url(ticket), params: {
      review_decision: "close",
      approval_user_id: @l3_user.id,
      help_desk_ticket: {
        response_message: "Issue reviewed and action has been completed."
      }
    }

    assert_response :unprocessable_entity
    assert_includes response.body, "must be requester or original submitter"

    ticket.reload
    assert_equal "submitted", ticket.status
    assert_nil ticket.approval_user_id
  end

  test "resolved ticket remains visible to reviewer with ticket details" do
    ticket = HelpDeskTicket.create!(
      user: @user,
      department: @department,
      request_type: "complaint",
      question_subject: "Laptop restart issue",
      message: "My laptop is still restarting unexpectedly."
    )

    sign_in @l1_user

    patch respond_help_desk_ticket_url(ticket), params: {
      help_desk_ticket: {
        response_message: "Issue has been fixed and verified."
      }
    }

    follow_redirect!

    assert_response :success
    assert_includes response.body, ticket.ticket_reference
    assert_includes response.body, "Last Support Update By"
    assert_includes response.body, "Issue has been fixed and verified."
  end

  test "selected action user can reopen a completed ticket back to the support level that completed it" do
    ticket = HelpDeskTicket.create!(
      user: @user,
      department: @department,
      request_type: "complaint",
      question_subject: "Scanner issue",
      message: "The scanner is still not working."
    )

    ticket.update!(current_escalation_position: 2, assigned_to_user: @l2_user)

    assert ticket.mark_resolved_by(
      reviewer: @l2_user,
      response_message: "Scanner settings have been refreshed.",
      final_action_mode: "reopen_close"
    )

    sign_in @user

    patch finalize_resolution_help_desk_ticket_url(ticket), params: {
      decision: "reopen",
      help_desk_ticket: {
        requester_remark: "Still seeing the same issue after trying again."
      }
    }

    assert_redirected_to help_desk_tickets_url

    ticket.reload
    assert_equal "reopened", ticket.status
    assert_equal @l2_user.id, ticket.assigned_to_user_id
    assert_equal 2, ticket.current_escalation_position
    assert_equal 1, ticket.reopen_count
    assert_equal "Still seeing the same issue after trying again.", ticket.requester_remark
  end

  test "selected action user can close a resolved ticket" do
    ticket = HelpDeskTicket.create!(
      user: @user,
      department: @department,
      request_type: "suggestion",
      question_subject: "Attendance report simplification",
      message: "Please simplify the attendance report."
    )

    assert ticket.mark_resolved_by(
      reviewer: @l1_user,
      response_message: "Attendance report has been simplified.",
      final_action_mode: "reopen_close"
    )

    sign_in @user

    patch finalize_resolution_help_desk_ticket_url(ticket), params: {
      decision: "close",
      help_desk_ticket: {
        requester_remark: ""
      }
    }

    assert_redirected_to help_desk_tickets_url

    ticket.reload
    assert_equal "closed", ticket.status
    assert_equal @user.id, ticket.closed_by_user_id
  end

  test "selected action user sees reopen and close actions after support closes the ticket" do
    ticket = HelpDeskTicket.create!(
      user: @user,
      department: @department,
      request_type: "complaint",
      question_subject: "Printer queue issue",
      message: "The printer queue keeps getting stuck."
    )

    travel_to(Time.current + 15.minutes) do
      assert ticket.mark_resolved_by(
        reviewer: @l1_user,
        response_message: "Queue service has been restarted.",
        final_action_mode: "reopen_close"
      )
    end

    sign_in @user

    get help_desk_tickets_url

    assert_response :success
    assert_includes response.body, 'data-helpdesk-menu-badge="1"'
    assert_includes response.body, ticket.ticket_reference
    assert_includes response.body, "Reopen Ticket"
    assert_includes response.body, "Close Ticket"
    assert_includes response.body, "24 hours"
  end

  test "selected action user sees reopen and close actions after support closes ticket" do
    ticket = HelpDeskTicket.create!(
      user: @user,
      department: @department,
      request_type: "complaint",
      question_subject: "Network patch issue",
      message: "Network patch issue should use reopen close flow."
    )

    assert ticket.mark_resolved_by(
      reviewer: @l1_user,
      response_message: "Network patch issue has been fixed.",
      final_action_mode: "reopen_close"
    )

    sign_in @user

    get help_desk_tickets_url

    assert_response :success
    assert_includes response.body, "Support has closed this ticket"
    assert_includes response.body, "Reopen Ticket"
    assert_includes response.body, "Close Ticket"
  end

  test "selected action user can close a support-closed ticket" do
    ticket = HelpDeskTicket.create!(
      user: @user,
      department: @department,
      request_type: "suggestion",
      question_subject: "Attendance report simplification",
      message: "Please simplify the attendance report."
    )

    assert ticket.mark_resolved_by(
      reviewer: @l1_user,
      response_message: "Attendance report has been simplified.",
      final_action_mode: "reopen_close"
    )

    sign_in @user

    patch finalize_resolution_help_desk_ticket_url(ticket), params: {
      decision: "close",
      help_desk_ticket: {
        requester_remark: ""
      }
    }

    assert_redirected_to help_desk_tickets_url

    ticket.reload
    assert_equal "closed", ticket.status
    assert_equal @user.id, ticket.closed_by_user_id
  end

  test "selected action user can reopen a support-closed ticket" do
    ticket = HelpDeskTicket.create!(
      user: @user,
      department: @department,
      request_type: "complaint",
      question_subject: "System access issue",
      message: "System access issue should reopen if still not fixed."
    )

    ticket.update!(current_escalation_position: 2, assigned_to_user: @l2_user)

    assert ticket.mark_resolved_by(
      reviewer: @l2_user,
      response_message: "System access issue has been handled.",
      final_action_mode: "reopen_close"
    )

    sign_in @user

    patch finalize_resolution_help_desk_ticket_url(ticket), params: {
      decision: "reopen",
      help_desk_ticket: {
        requester_remark: "Access issue is still happening for me."
      }
    }

    assert_redirected_to help_desk_tickets_url

    ticket.reload
    assert_equal "reopened", ticket.status
    assert_equal @l2_user.id, ticket.assigned_to_user_id
    assert_equal 2, ticket.current_escalation_position
    assert_equal 1, ticket.reopen_count
  end

  test "reviewer can choose original submitter as action user" do
    ticket = HelpDeskTicket.create!(
      user: @user,
      submitted_by_user: @submitter_user,
      department: @department,
      request_type: "complaint",
      question_subject: "Laptop issue",
      message: "Laptop issue was raised on behalf of requester."
    )

    sign_in @l2_user

    patch respond_help_desk_ticket_url(ticket), params: {
      review_decision: "close",
      approval_user_id: @submitter_user.id,
      help_desk_ticket: {
        response_message: "Laptop has been configured and is ready."
      }
    }

    assert_redirected_to help_desk_tickets_url

    ticket.reload
    assert_equal "resolved", ticket.status
    assert_equal @submitter_user.id, ticket.approval_user_id

    sign_in @submitter_user
    get help_desk_tickets_url

    assert_response :success
    assert_includes response.body, "Support has closed this ticket"
    assert_includes response.body, "Reopen Ticket"
    assert_includes response.body, "Close Ticket"
  end

  test "action user does not see reopen close actions while support keeps the ticket open" do
    ticket = HelpDeskTicket.create!(
      user: @user,
      department: @department,
      request_type: "complaint",
      question_subject: "System hanging",
      message: "The system is still hanging during login."
    )

    assert ticket.keep_open_by(
      reviewer: @l1_user,
      response_message: "We are still investigating the login service and keeping this ticket open."
    )

    sign_in @user

    get help_desk_tickets_url

    assert_response :success
    assert_includes response.body, ticket.ticket_reference
    assert_includes response.body, "Open With Support"
    assert_includes response.body, "No reopen or close action is needed right now because support has kept the ticket open."
    assert_not_includes response.body, "Support has closed this ticket"
  end

  test "shows common question field on help desk form" do
    sign_in @user

    get help_desk_tickets_url

    assert_response :success
    assert_includes response.body, "Common Question / Topic"
    assert_includes response.body, "Other / Type your own topic"
  end
end
