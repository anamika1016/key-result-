require "test_helper"

class TrainingsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      email: "training.employee@example.com",
      employee_code: "TRN001",
      password: "password123",
      password_confirmation: "password123",
      role: "employee"
    )
  end

  test "individual certificate is blocked until every training in that month is complete" do
    first_training = create_training!("May Cyber Safety")
    create_training!("May Policy Refresher")

    complete_training_for(@user, first_training)
    sign_in @user, scope: :user

    get certificate_training_url(first_training, format: :pdf)

    assert_redirected_to trainings_url
    assert_includes flash[:alert], "Completed 1 of 2"
  end

  test "individual certificate URL redirects to monthly certificate after all month trainings are complete" do
    first_training = create_training!("May Cyber Safety")
    second_training = create_training!("May Policy Refresher")

    complete_training_for(@user, first_training)
    complete_training_for(@user, second_training)
    sign_in @user, scope: :user

    get certificate_training_url(first_training, format: :pdf)

    assert_redirected_to monthly_certificate_trainings_path(year: 2026, month: 5, format: :pdf)
  end

  test "certificate is blocked when a monthly training assessment is not submitted" do
    first_training = create_training!("May Cyber Safety", has_assessment: true)
    second_training = create_training!("May Policy Refresher", has_assessment: true)
    create_question_for(first_training)
    create_question_for(second_training)

    complete_training_for(@user, first_training, score: 1)
    complete_training_for(@user, second_training)
    sign_in @user, scope: :user

    get certificate_training_url(first_training, format: :pdf)

    assert_redirected_to trainings_url
    assert_includes flash[:alert], "Completed 1 of 2"
  end

  test "assessment result hides certificate button while another monthly assessment is pending" do
    first_training = create_training!("May Cyber Safety", has_assessment: true)
    second_training = create_training!("May Policy Refresher", has_assessment: true)
    first_question = create_question_for(first_training)
    create_question_for(second_training)

    complete_training_for(@user, second_training)
    sign_in @user, scope: :user

    post submit_assessment_training_url(first_training),
         params: { answers: { first_question.id.to_s => "Complete training" } }

    assert_response :success
    assert_no_match "Download Certificate", response.body
    assert_match "Certificate will be available after completing all trainings and assessments for this month.", response.body
  end

  private

  def create_training!(title, has_assessment: false)
    Training.create!(
      title: title,
      description: "Monthly training",
      duration: 60,
      month: 5,
      year: 2026,
      status: true,
      has_assessment: has_assessment,
      created_by: @user.id
    )
  end

  def complete_training_for(user, training, score: nil)
    UserTrainingProgress.create!(
      user: user,
      training: training,
      status: "completed",
      started_at: 1.hour.ago,
      ended_at: Time.current,
      time_spent: training.duration,
      financial_year: "2026-27",
      score: score
    )
  end

  def create_question_for(training)
    TrainingQuestion.create!(
      training: training,
      question: "What should you do?",
      option_a: "Complete training",
      option_b: "Skip training",
      correct_answer: "Complete training"
    )
  end
end
