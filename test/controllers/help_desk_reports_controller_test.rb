require "test_helper"

class HelpDeskReportsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @department = Department.create!(
      department_type: "Administration",
      theme_id: 310,
      theme_name: "Support"
    )

    @user = User.create!(
      email: "report.user@example.com",
      employee_code: "EMP777",
      password: "password123",
      password_confirmation: "password123",
      role: "employee"
    )

    @l1_user = User.create!(
      email: "report.l1@example.com",
      employee_code: "L1777",
      password: "password123",
      password_confirmation: "password123",
      role: "employee"
    )

    EmployeeDetail.create!(
      user: @user,
      employee_name: "Report User",
      employee_email: @user.email,
      employee_code: @user.employee_code,
      department: "Administration"
    )

    HelpdeskEscalationMatrix.create!(
      department: @department,
      escalation_levels_attributes: [
        { position: 1, user_id: @l1_user.id }
      ]
    )
  end

  test "help desk report shows current and closed ticket history" do
    current_ticket = HelpDeskTicket.create!(
      user: @user,
      department: @department,
      request_type: "complaint",
      question_subject: "Current network issue",
      message: "Internet is unstable right now."
    )

    closed_ticket = HelpDeskTicket.create!(
      user: @user,
      department: @department,
      request_type: "suggestion",
      question_subject: "Old dashboard suggestion",
      message: "Please simplify the dashboard widgets."
    )

    assert closed_ticket.mark_resolved_by(
      reviewer: @l1_user,
      response_message: "Dashboard widgets were simplified."
    )
    assert closed_ticket.close_by!(actor: @user)

    sign_in @user

    get help_desk_reports_url

    assert_response :success
    assert_includes response.body, "Help Desk Report"
    assert_includes response.body, current_ticket.ticket_reference
    assert_includes response.body, closed_ticket.ticket_reference
    assert_includes response.body, "Saved Ticket History"
  end

  test "help desk report shows every support update with its date and time" do
    ticket = HelpDeskTicket.create!(
      user: @user,
      department: @department,
      request_type: "complaint",
      question_subject: "Repeated internet issue",
      message: "Internet is disconnecting again."
    )

    travel_to(Time.zone.local(2026, 5, 25, 15, 13, 0)) do
      assert ticket.keep_open_by(
        reviewer: @l1_user,
        response_message: "Initial check is done."
      )
    end

    travel_to(Time.zone.local(2026, 5, 25, 15, 21, 0)) do
      assert ticket.mark_resolved_by(
        reviewer: @l1_user,
        response_message: "Cable replacement is done."
      )
    end

    sign_in @user

    get help_desk_reports_url

    assert_response :success
    assert_includes response.body, "Support Updates"
    assert_includes response.body, "Initial check is done."
    assert_includes response.body, "Cable replacement is done."
    assert_includes response.body, "25 May 2026, 03:13 PM"
    assert_includes response.body, "25 May 2026, 03:21 PM"
  end

  test "help desk current page hides closed tickets but report keeps them" do
    current_ticket = HelpDeskTicket.create!(
      user: @user,
      department: @department,
      request_type: "complaint",
      question_subject: "System access issue",
      message: "Access is pending for the current system."
    )

    closed_ticket = HelpDeskTicket.create!(
      user: @user,
      department: @department,
      request_type: "complaint",
      question_subject: "Resolved printer issue",
      message: "Printer issue has already been resolved."
    )

    assert closed_ticket.mark_resolved_by(
      reviewer: @l1_user,
      response_message: "Printer service was fixed."
    )
    assert closed_ticket.close_by!(actor: @user)

    sign_in @user

    get help_desk_tickets_url

    assert_response :success
    assert_includes response.body, current_ticket.ticket_reference
    assert_not_includes response.body, closed_ticket.ticket_reference
    assert_includes response.body, "Open Help Desk Report"

    get help_desk_reports_url, params: { status: "closed" }

    assert_response :success
    assert_includes response.body, closed_ticket.ticket_reference
    assert_not_includes response.body, current_ticket.ticket_reference
  end

  test "help desk report can be downloaded in excel format" do
    ticket = HelpDeskTicket.create!(
      user: @user,
      department: @department,
      request_type: "complaint",
      question_subject: "Excel export issue",
      message: "Need report export for this ticket."
    )

    sign_in @user

    get help_desk_reports_url(format: :xlsx, status: "submitted")

    assert_response :success
    assert_includes response.headers["Content-Disposition"], ".xlsx"
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", response.media_type
    assert_not_nil ticket.ticket_reference
  end
end
