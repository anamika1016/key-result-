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

    @oral_l1_user = User.create!(
      email: "manager.helpdesk@example.com",
      employee_code: "M1001",
      password: "password123",
      password_confirmation: "password123",
      role: "employee"
    )

    EmployeeDetail.create!(
      user: @user,
      employee_name: "Help Desk Employee",
      employee_email: @user.email,
      employee_code: @user.employee_code,
      department: "IT Support",
      l1_code: @oral_l1_user.employee_code,
      l1_employer_name: @oral_l1_user.email
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

  test "complaint can be assigned directly to selected escalation level" do
    ticket = HelpDeskTicket.create!(
      user: @user,
      department: @department,
      request_type: "complaint",
      initial_escalation_position: "2",
      question_subject: "Urgent payroll issue",
      message: "This complaint should start with L2."
    )

    assert_equal 2, ticket.current_escalation_position
    assert_equal @l2_user.id, ticket.assigned_to_user_id
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

  test "user side visibility excludes support-only assignments" do
    ticket = HelpDeskTicket.create!(
      user: @user,
      department: @department,
      request_type: "complaint",
      question_subject: "Laptop issue",
      message: "Laptop is not charging."
    )

    assert_equal @l1_user.id, ticket.assigned_to_user_id
    assert_includes HelpDeskTicket.user_side_visible_to_actor(@user), ticket
    assert_not_includes HelpDeskTicket.user_side_visible_to_actor(@l1_user), ticket
    assert_not_includes HelpDeskTicket.user_side_visible_to_actor(@l3_user), ticket
  end

  test "user side visibility ignores mismatched stored owner when requester belongs to another user" do
    ticket = HelpDeskTicket.create!(
      user: @user,
      department: @department,
      request_type: "complaint",
      question_subject: "Laptop issue",
      message: "Laptop is not charging."
    )

    ticket.update_columns(
      user_id: @l1_user.id,
      requester_email: @user.email,
      requester_employee_code: @user.employee_code
    )

    assert_not_includes HelpDeskTicket.user_side_visible_to_actor(@l1_user), ticket
    assert_not ticket.reload.visible_in_user_current_list_for?(@l1_user)
    assert_includes HelpDeskTicket.user_side_visible_to_actor(@user), ticket
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
      assert_equal 1, ticket.support_updates.count
      assert_equal "We are still working on the dashboard updates.", ticket.support_updates.last.message
    end
  end

  test "support updates are kept as dated history instead of being overwritten" do
    ticket = HelpDeskTicket.create!(
      user: @user,
      department: @department,
      request_type: "suggestion",
      question_subject: "Dashboard improvement",
      message: "Please improve the support request dashboard."
    )

    travel_to(Time.zone.local(2026, 5, 25, 10, 30, 0)) do
      assert ticket.keep_open_by(
        reviewer: @l1_user,
        response_message: "First support update."
      )
    end

    travel_to(Time.zone.local(2026, 5, 25, 11, 45, 0)) do
      assert ticket.mark_resolved_by(
        reviewer: @l1_user,
        response_message: "Final support update."
      )
    end

    ticket.reload

    assert_equal "Final support update.", ticket.response_message
    assert_equal [ "First support update.", "Final support update." ], ticket.support_update_history.map(&:message)
    assert_equal Time.zone.local(2026, 5, 25, 11, 45, 0), ticket.latest_support_update.created_at
  end

  test "requester remarks are kept as dated history instead of being overwritten" do
    ticket = HelpDeskTicket.create!(
      user: @user,
      department: @department,
      request_type: "complaint",
      question_subject: "Printer issue",
      message: "Printer is still not working."
    )

    travel_to(Time.zone.local(2026, 5, 25, 10, 30, 0)) do
      assert ticket.mark_resolved_by(
        reviewer: @l1_user,
        response_message: "Printer has been checked.",
        final_action_mode: "reopen_close"
      )
    end

    travel_to(Time.zone.local(2026, 5, 25, 11, 0, 0)) do
      assert ticket.reopen_by!(
        actor: @user,
        remark: "Still not resolved."
      )
    end

    travel_to(Time.zone.local(2026, 5, 25, 11, 30, 0)) do
      assert ticket.mark_resolved_by(
        reviewer: @l1_user,
        response_message: "Printer spooler has been reset.",
        final_action_mode: "reopen_close"
      )
    end

    travel_to(Time.zone.local(2026, 5, 25, 12, 0, 0)) do
      assert ticket.reopen_by!(
        actor: @user,
        remark: "Still not resolved yet."
      )
    end

    ticket.reload

    assert_equal "Still not resolved yet.", ticket.requester_remark
    assert_equal [ "Still not resolved.", "Still not resolved yet." ], ticket.requester_remark_history.map(&:message)
    assert_equal [ "Still not resolved yet.", "Still not resolved." ], ticket.requester_remark_history_latest_first.map(&:message)
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

  test "second failed response at a level reopens with next escalation level" do
    ticket = HelpDeskTicket.create!(
      user: @user,
      department: @department,
      request_type: "complaint",
      question_subject: "Recurring network issue",
      message: "Network keeps failing."
    )

    assert ticket.mark_resolved_by(
      reviewer: @l1_user,
      response_message: "Network cable replaced.",
      final_action_mode: "reopen_close"
    )
    assert ticket.reopen_by!(actor: @user, remark: "Issue still exists.")
    assert_equal @l1_user.id, ticket.reload.assigned_to_user_id

    assert ticket.mark_resolved_by(
      reviewer: @l1_user,
      response_message: "Switch port changed.",
      final_action_mode: "reopen_close"
    )
    assert ticket.reopen_by!(actor: @user, remark: "Still not resolved.")

    ticket.reload
    assert_equal 2, ticket.current_escalation_position
    assert_equal @l2_user.id, ticket.assigned_to_user_id
    assert_equal({ "1" => 2 }, ticket.failed_response_counts)
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

  test "ticket pending user action auto closes after 2 days if selected user does not respond" do
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

    assert_in_delta 2.days.from_now.to_i, ticket.requester_response_due_at.to_i, 2

    travel_to(ticket.requester_response_due_at + 5.minutes) do
      assert ticket.auto_close_if_requester_inactive!(reference_time: Time.current)

      ticket.reload
      assert_equal "closed", ticket.status
      assert ticket.closed_automatically
      assert_equal Time.current, ticket.closed_at
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

  test "captures oral response ticket timestamp and sends it for approval" do
    freeze_time do
      ticket = HelpDeskTicket.new(
        user: @user,
        submitted_by_user: @oral_l1_user,
        department: @department,
        request_type: "complaint",
        question_subject: "Walk-in complaint",
        message: "Employee shared this issue verbally with the manager.",
        on_behalf_requested: "1",
        request_received_on: "2026-05-10",
        request_received_time: "14:35"
      )
      ticket.prepare_assisted_resolution!(resolver: @oral_l1_user)
      ticket.save!

      assert ticket.assisted_request?
      assert_equal "Oral Response Ticket", ticket.submission_mode_label
      assert_equal "resolved", ticket.status
      assert_equal "approve_reject", ticket.final_action_mode
      assert_equal @user.id, ticket.approval_user_id
      assert_nil ticket.assigned_to_user_id
      assert_nil ticket.escalation_due_at
      assert_equal Date.new(2026, 5, 10), ticket.request_received_at.in_time_zone("Asia/Kolkata").to_date
      assert_equal "14:35", ticket.request_received_at.in_time_zone("Asia/Kolkata").strftime("%H:%M")
    end
  end

  test "oral response ticket requires manual date and time" do
    ticket = HelpDeskTicket.new(
      user: @user,
      submitted_by_user: @oral_l1_user,
      department: @department,
      request_type: "suggestion",
      question_subject: "Verbal suggestion",
      message: "Employee shared this suggestion verbally.",
      on_behalf_requested: "1"
    )
    ticket.prepare_assisted_resolution!(resolver: @oral_l1_user)

    assert_not ticket.valid?
    assert_includes ticket.errors[:request_received_on], "Select the request date for this oral ticket."
    assert_includes ticket.errors[:request_received_time], "Select the request time for this oral ticket."
  end

  test "requester can reject an oral response ticket back to the resolver" do
    ticket = HelpDeskTicket.new(
      user: @user,
      submitted_by_user: @oral_l1_user,
      department: @department,
      request_type: "suggestion",
      question_subject: "Verbal suggestion",
      message: "Employee shared this suggestion verbally.",
      on_behalf_requested: "1",
      request_received_on: "2026-05-10",
      request_received_time: "14:35"
    )
    ticket.prepare_assisted_resolution!(resolver: @oral_l1_user)
    ticket.save!

    assert ticket.reject_by!(actor: @user, remark: "This work is not completed yet.")

    ticket.reload
    assert_equal "reopened", ticket.status
    assert_equal @oral_l1_user.id, ticket.assigned_to_user_id
    assert_nil ticket.escalation_due_at
    assert_equal "This work is not completed yet.", ticket.requester_remark
  end

  test "requester identity can approve oral response ticket even when login user id differs" do
    alternate_login = User.create!(
      email: "alternate.helpdesk.employee@example.com",
      employee_code: @user.employee_code,
      password: "password123",
      password_confirmation: "password123",
      role: "employee"
    )

    ticket = HelpDeskTicket.new(
      user: @user,
      submitted_by_user: @oral_l1_user,
      department: @department,
      request_type: "complaint",
      question_subject: "Walk-in complaint",
      message: "Employee shared this issue verbally with the manager.",
      on_behalf_requested: "1",
      request_received_on: "2026-05-10",
      request_received_time: "14:35"
    )
    ticket.prepare_assisted_resolution!(resolver: @oral_l1_user)
    ticket.save!

    assert_includes HelpDeskTicket.visible_to_actor(alternate_login), ticket
    assert_includes HelpDeskTicket.pending_user_action_for(alternate_login), ticket
    assert ticket.can_be_finalized_by?(alternate_login)
  end
end
