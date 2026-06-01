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
    sign_in @hod, scope: :user

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

  test "hod can import help desk questions from csv" do
    sign_in @hod, scope: :user

    file = Tempfile.new([ "help_desk_questions", ".csv" ])
    file.write("Department,Request Type,Question,Active\nFinance,Complaint,Payment status not updated,Yes\n")
    file.rewind

    assert_difference("HelpDeskQuestionMaster.count", 1) do
      post import_help_desk_question_masters_url, params: {
        file: Rack::Test::UploadedFile.new(file.path, "text/csv")
      }
    end

    question = HelpDeskQuestionMaster.last

    assert_redirected_to help_desk_question_masters_url
    assert_equal @department, question.department
    assert_equal "complaint", question.request_type
    assert_equal "Payment status not updated", question.question_text
    assert_predicate question, :active?
  ensure
    file&.close
    file&.unlink
  end

  test "employee cannot access help desk question master page" do
    sign_in @employee, scope: :user

    get help_desk_question_masters_url

    assert_redirected_to root_url
  end
end
