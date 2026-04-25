require "test_helper"

class QuizAccessControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  test "shows employee profile after successful quiz start" do
    post start_quiz_access_path(quizzes(:one).qr_token), params: {
      employee_code: user_quizzes(:one).employee_code,
      password: user_quizzes(:one).password
    }

    follow_redirect!

    assert_response :success
    assert_includes response.body, user_quizzes(:one).name
    assert_includes response.body, user_quizzes(:one).designation
    assert_includes response.body, user_quizzes(:one).employee_code
    assert_includes response.body, "data-quiz-timer-display"
    assert_includes response.body, "istockphoto-"
  end

  test "submits quiz once and blocks repeat attempt" do
    quiz = quizzes(:one)
    user_quiz = user_quizzes(:one)
    question = questions(:one)

    post start_quiz_access_path(quiz.qr_token), params: {
      employee_code: user_quiz.employee_code,
      password: user_quiz.password
    }
    follow_redirect!

    assert_difference("QuizSubmission.count", 1) do
      post submit_quiz_access_path(quiz.qr_token), params: {
        answers: {
          question.id.to_s => question.correct_answer
        }
      }
    end

    assert_response :success
    assert_equal quiz.id, QuizSubmission.last.quiz_id
    assert_equal user_quiz.employee_code, QuizSubmission.last.employee_code
    assert_equal 1, QuizSubmission.last.score

    post start_quiz_access_path(quiz.qr_token), params: {
      employee_code: user_quiz.employee_code,
      password: user_quiz.password
    }

    follow_redirect!

    assert_response :success
    assert_includes response.body, "already submit"
    assert_no_difference("QuizSubmission.count") do
      post submit_quiz_access_path(quiz.qr_token), params: {
        answers: {
          question.id.to_s => question.correct_answer
        }
      }
    end

    assert_redirected_to quiz_access_path(quiz.qr_token)
  end

  test "shows reduced remaining time as quiz stays in progress" do
    quiz = quizzes(:one)
    user_quiz = user_quizzes(:one)

    post start_quiz_access_path(quiz.qr_token), params: {
      employee_code: user_quiz.employee_code,
      password: user_quiz.password
    }
    follow_redirect!

    travel 2.minutes do
      assert_no_difference("QuizSubmission.count") do
        get quiz_access_path(quiz.qr_token)
      end
    end

    assert_response :success
    assert_includes response.body, "Submit Quiz"
    assert_match(/data-time-remaining-seconds=\"1(7|8|9)\d\"|data-time-remaining-seconds=\"180\"/, response.body)
  end

  test "reopens quiz when old accidental blank submission exists" do
    quiz = quizzes(:one)
    user_quiz = user_quizzes(:one)

    accidental_submission = QuizSubmission.create!(
      quiz: quiz,
      user_quiz: user_quiz,
      user: user_quiz.user,
      employee_code: user_quiz.employee_code,
      name: user_quiz.name,
      status: "completed",
      score: 0,
      submitted_answers: {},
      submitted_at: Time.current
    )

    user_quiz.update!(
      quiz: quiz,
      score: 0,
      status: "completed",
      submitted_answers: {},
      submitted_at: accidental_submission.submitted_at
    )

    assert_difference("QuizSubmission.count", -1) do
      post start_quiz_access_path(quiz.qr_token), params: {
        employee_code: user_quiz.employee_code,
        password: user_quiz.password
      }
    end

    follow_redirect!

    assert_response :success
    assert_includes response.body, "Submit Quiz"
    assert_nil user_quiz.reload.status
    assert_equal({}, user_quiz.submitted_answers)
  end
end
