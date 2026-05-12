require "test_helper"

class HelpDeskQuestionMasterTest < ActiveSupport::TestCase
  setup do
    @department = Department.create!(
      department_type: "HR",
      theme_id: 401,
      theme_name: "People"
    )
  end

  test "assigns default position within department and request type" do
    HelpDeskQuestionMaster.create!(
      department: @department,
      request_type: "complaint",
      question_text: "Salary credited late"
    )

    question = HelpDeskQuestionMaster.create!(
      department: @department,
      request_type: "complaint",
      question_text: "PF statement required",
      position: nil
    )

    assert_equal 2, question.position
  end

  test "requires unique question text for department and request type" do
    HelpDeskQuestionMaster.create!(
      department: @department,
      request_type: "suggestion",
      question_text: "Improve induction process"
    )

    duplicate = HelpDeskQuestionMaster.new(
      department: @department,
      request_type: "suggestion",
      question_text: "  Improve induction process  "
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:question_text], "has already been taken"
  end
end
