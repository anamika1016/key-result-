require "test_helper"

class QuizSubmissionTest < ActiveSupport::TestCase
  test "allows only one submission per employee for a quiz" do
    existing_submission = quiz_submissions(:completed_one)

    duplicate_submission = QuizSubmission.new(
      quiz: existing_submission.quiz,
      user_quiz: user_quizzes(:one),
      employee_code: existing_submission.employee_code,
      name: "Another Attempt",
      status: "completed",
      submitted_at: Time.current
    )

    assert_not duplicate_submission.valid?
    assert_includes duplicate_submission.errors[:employee_code], "has already been taken"
  end
end
