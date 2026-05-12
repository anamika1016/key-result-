require "test_helper"

class HelpDeskQuestionMastersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @department = Department.create!(
      department_type: "Finance",
      theme_id: 402,
      theme_name: "Operations"
    )

    @hod = User.create!(
      email: "question.master.hod@example.com",
      employee_code: "HOD401",
      password: "password123",
      password_confirmation: "password123",
      role: "hod"
    )

    @employee = User.create!(
      email: "question.master.employee@example.com",
      employee_code: "EMP401",
      password: "password123",
      password_confirmation: "password123",
      role: "employee"
    )
  end

  test "hod can create help desk question master" do
    sign_in @hod

    assert_difference("HelpDeskQuestionMaster.count", 1) do
      post help_desk_question_masters_url, params: {
        help_desk_question_master: {
          department_id: @department.id,
          request_type: "complaint",
          question_text: "Reimbursement not received",
          position: 1,
          active: "1"
        }
      }
    end

    assert_redirected_to help_desk_question_masters_url
  end

  test "employee cannot access help desk question master page" do
    sign_in @employee

    get help_desk_question_masters_url

    assert_redirected_to root_url
  end
end
