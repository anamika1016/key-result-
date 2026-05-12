require "test_helper"

class HelpDeskTicketTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @department = Department.create!(
      department_type: "IT Support",
      theme_id: 101,
      theme_name: "Operations"
    )

    @user = User.create!(
      email: "helpdesk.employee@example.com",
      employee_code: "EMP900",
      password: "password123",
      password_confirmation: "password123",
      role: "employee"
    )

    @l1_user = User.create!(
      email: "l1.helpdesk@example.com",
      employee_code: "L1001",
      password: "password123",
      password_confirmation: "password123",
      role: "employee"
    )

    @l2_user = User.create!(
      email: "l2.helpdesk@example.com",
      employee_code: "L2001",
      password: "password123",
      password_confirmation: "password123",
      role: "employee"
    )

    @l3_user = User.create!(
      email: "l3.helpdesk@example.com",
      employee_code: "L3001",
      password: "password123",
      password_confirmation: "password123",
      role: "hod"
    )

    EmployeeDetail.create!(
      user: @user,
      employee_name: "Help Desk Employee",
      employee_email: @user.email,
      employee_code: @user.employee_code,
      department: "IT Support"
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
      question_text: "Internet is not working",
      position: 1
    )
  end

  test "captures requester information and assigns first escalation from matrix" do
    freeze_time do
      ticket = HelpDeskTicket.create!(
        user: @user,
        department: @department,
        request_type: "complaint",
        question_subject: "Printer issue",
        message: "Printer is not working on the second floor."
      )

      assert_equal "Help Desk Employee", ticket.requester_name
      assert_equal "helpdesk.employee@example.com", ticket.requester_email
      assert_equal "EMP900", ticket.requester_employee_code
      assert_equal "submitted", ticket.status
      assert_equal 1, ticket.current_escalation_position
      assert_equal @l1_user.id, ticket.assigned_to_user_id
      assert_equal Time.current + 2.days, ticket.escalation_due_at
    end
  end

  test "auto escalates to next level after two days without response" do
    ticket = HelpDeskTicket.create!(
      user: @user,
      department: @department,
      request_type: "complaint",
      question_subject: "Laptop boot issue",
      message: "My laptop is not booting."
    )

    travel_to(ticket.escalation_due_at + 5.minutes) do
      assert ticket.auto_escalate_if_due!

      ticket.reload
      assert_equal 2, ticket.current_escalation_position
      assert_equal @l2_user.id, ticket.assigned_to_user_id
      assert_equal "in_review", ticket.status
    end
  end

  test "reviewer can still see resolved tickets in visible history" do
    ticket = HelpDeskTicket.create!(
      user: @user,
      department: @department,
      request_type: "suggestion",
      question_subject: "Dashboard improvement",
      message: "Please improve the support request dashboard."
    )

    assert_includes HelpDeskTicket.visible_to_actor(@l1_user), ticket

    assert ticket.mark_resolved_by(
      reviewer: @l1_user,
      response_message: "Reviewed and completed."
    )

    ticket.reload

    assert_includes HelpDeskTicket.visible_to_actor(@l1_user), ticket
  end

  test "reviewer can keep a ticket open without sending it for user action" do
    freeze_time do
      ticket = HelpDeskTicket.create!(
        user: @user,
        department: @department,
        request_type: "suggestion",
        question_subject: "Dashboard improvement",
        message: "Please improve the support request dashboard."
      )

      assert ticket.keep_open_by(
        reviewer: @l1_user,
        response_message: "We are still working on the dashboard updates."
      )

      ticket.reload

      assert_equal "in_review", ticket.status
      assert_equal @l1_user.id, ticket.responded_by_user_id
      assert_equal @l1_user.id, ticket.assigned_to_user_id
      assert_equal Time.current + 2.days, ticket.escalation_due_at
      assert_nil ticket.requester_response_due_at
    end
  end

  test "selected action user can reopen a resolved ticket and send it back to the support level that completed it" do
    ticket = HelpDeskTicket.create!(
      user: @user,
      department: @department,
      request_type: "complaint",
      question_subject: "Biometric device issue",
      message: "The biometric device is still failing."
    )

    ticket.update!(current_escalation_position: 2, assigned_to_user: @l2_user)

    assert ticket.mark_resolved_by(
      reviewer: @l2_user,
      response_message: "Device has been reset. Please try again.",
      final_action_mode: "reopen_close"
    )

    travel_to(Time.current + 30.minutes) do
      assert ticket.reopen_by!(
        actor: @user,
        remark: "The problem is still happening after the reset."
      )

      ticket.reload
      assert_equal "reopened", ticket.status
      assert_equal @l2_user.id, ticket.assigned_to_user_id
      assert_equal 2, ticket.current_escalation_position
      assert_equal 1, ticket.reopen_count
      assert_equal "The problem is still happening after the reset.", ticket.requester_remark
      assert_equal Time.current + 2.days, ticket.escalation_due_at
      assert_nil ticket.requester_response_due_at
    end
  end

  test "reviewer can send a ticket to the original submitter for user action" do
    submitter = User.create!(
      email: "submitter.helpdesk@example.com",
      employee_code: "SUB001",
      password: "password123",
      password_confirmation: "password123",
      role: "employee"
    )

    ticket = HelpDeskTicket.create!(
      user: @user,
      submitted_by_user: submitter,
      department: @department,
      request_type: "complaint",
      question_subject: "Proxy access issue",
      message: "Proxy access is not working for the requester."
    )

    assert ticket.mark_resolved_by(
      reviewer: @l2_user,
      response_message: "Proxy access has been fixed.",
      approval_user: submitter
    )

    ticket.reload
    assert_equal "resolved", ticket.status
    assert_equal submitter.id, ticket.approval_user_id
    assert_equal "reopen_close", ticket.final_action_mode
    assert ticket.can_be_finalized_by?(submitter)
    assert_not ticket.can_be_finalized_by?(@user)
  end

  test "ticket pending user action auto closes after 24 hours if selected user does not respond" do
    freeze_time do
      ticket = HelpDeskTicket.create!(
        user: @user,
        department: @department,
        request_type: "suggestion",
        question_subject: "Onboarding improvement",
        message: "Please improve the onboarding steps."
      )

      assert ticket.mark_resolved_by(
        reviewer: @l1_user,
        response_message: "The onboarding steps have been updated.",
        final_action_mode: "reopen_close"
      )

      assert_equal Time.current + 24.hours, ticket.requester_response_due_at

      travel_to(ticket.requester_response_due_at + 5.minutes) do
        assert ticket.auto_close_if_requester_inactive!(reference_time: Time.current)

        ticket.reload
        assert_equal "closed", ticket.status
        assert ticket.closed_automatically
        assert_equal Time.current, ticket.closed_at
      end
    end
  end

  test "reviewer can close a ticket from support side with reopen close mode" do
    ticket = HelpDeskTicket.create!(
      user: @user,
      department: @department,
      request_type: "complaint",
      question_subject: "System printer issue",
      message: "Printer issue should use the reopen close path."
    )

    assert ticket.mark_resolved_by(
      reviewer: @l1_user,
      response_message: "Printer issue has been resolved from support side."
    )

    ticket.reload
    assert_equal "resolved", ticket.status
    assert_equal "reopen_close", ticket.final_action_mode
    assert_equal @user.id, ticket.approval_user_id
    assert_equal 0, ticket.reopen_count
  end

  test "requires configured escalation matrix for selected department" do
    new_department = Department.create!(
      department_type: "Finance",
      theme_id: 102,
      theme_name: "Operations"
    )

    ticket = HelpDeskTicket.new(
      user: @user,
      department: new_department,
      request_type: "suggestion",
      question_subject: "Reimbursement workflow",
      message: "Please add a faster reimbursement workflow."
    )

    assert_not ticket.valid?
    assert_includes ticket.errors[:department_id], "does not have a configured helpdesk escalation matrix"
  end

  test "copies question subject from selected help desk question master" do
    ticket = HelpDeskTicket.create!(
      user: @user,
      department: @department,
      request_type: "complaint",
      help_desk_question_master: @question_master,
      message: "Wi-Fi keeps disconnecting every 10 minutes."
    )

    assert_equal "Internet is not working", ticket.question_subject
  end

  test "requires question subject when no master question is selected" do
    ticket = HelpDeskTicket.new(
      user: @user,
      department: @department,
      request_type: "complaint",
      message: "Need help with the local network."
    )

    assert_not ticket.valid?
    assert_includes ticket.errors[:question_subject], "Select a common question or type your own topic."
  end
end
