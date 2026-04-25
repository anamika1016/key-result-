class QuizAccessController < ApplicationController
  skip_before_action :authenticate_user!

  before_action :set_quiz

  def show
    @user_quiz = UserQuiz.new
    @authenticated_user_quiz = current_user_quiz
    @quiz_submission = current_quiz_submission

    return unless @authenticated_user_quiz.present? && @quiz_submission.blank?

    @quiz_play_state = ensure_quiz_play_state!(@authenticated_user_quiz)

    @ordered_questions = ordered_questions_for(@quiz_play_state)
    @question_media_map = question_media_map_for(@ordered_questions, @quiz_play_state)
    @quiz_duration_seconds = quiz_duration_seconds
    @quiz_started_at = quiz_started_at_for(@quiz_play_state)
    @quiz_deadline_at = @quiz_started_at + @quiz_duration_seconds
    @quiz_seconds_remaining = quiz_seconds_remaining(@quiz_started_at, @quiz_duration_seconds)
  end

  def start
    if params[:employee_code].to_s.strip.blank? || params[:password].to_s.strip.blank?
      @user_quiz = UserQuiz.new
      @authenticated_user_quiz = nil
      @quiz_submission = nil
      flash.now[:alert] = "Please enter employee code and password first."
      render :show, status: :unprocessable_entity
      return
    end

    @user_quiz = find_user_quiz

    unless @user_quiz&.valid_quiz_password?(params[:password])
      @authenticated_user_quiz = nil
      @quiz_submission = nil
      flash.now[:alert] = "Invalid employee code or password."
      render :show, status: :unprocessable_entity
      return
    end

    if quiz_submission_for(@user_quiz).present?
      session[quiz_session_key] = @user_quiz.id
      redirect_to quiz_access_path(@quiz.qr_token), alert: "You have already submitted this quiz once."
    else
      session[quiz_session_key] = @user_quiz.id
      ensure_quiz_play_state!(@user_quiz)
      redirect_to quiz_access_path(@quiz.qr_token), notice: "Quiz opened successfully."
    end
  end

  def submit
    @authenticated_user_quiz = current_user_quiz

    unless @authenticated_user_quiz
      redirect_to quiz_access_path(@quiz.qr_token), alert: "Please enter employee code and password first."
      return
    end

    if current_quiz_submission.present?
      redirect_to quiz_access_path(@quiz.qr_token), alert: "You have already submitted this quiz once."
      return
    end

    submitted_answers = extract_answers

    begin
      @quiz_submission = complete_quiz_submission!(@authenticated_user_quiz, submitted_answers)
    rescue ActiveRecord::ActiveRecordError => error
      message = @quiz_submission&.errors&.full_messages&.to_sentence.presence || error.message
      redirect_to quiz_access_path(@quiz.qr_token), alert: message
      return
    end

    redirect_to quiz_access_result_path(@quiz.qr_token, @quiz_submission.id), notice: "Quiz submitted successfully."
  end

  def logout
    clear_quiz_access_session!
    redirect_to quiz_access_path(@quiz.qr_token), notice: "Quiz session logged out successfully."
  end

  def result
    @quiz_submission = @quiz.quiz_submissions.find(params[:submission_id])
    @result = {
      score: @quiz_submission.score,
      total: @quiz.questions.count,
      answers: @quiz_submission.submitted_answers
    }
  end

  private

  def set_quiz
    @quiz = Quiz.find_by!(qr_token: params[:qr_token])
  end

  def find_user_quiz
    normalized_code = params[:employee_code].to_s.strip
    UserQuiz.find_by("LOWER(TRIM(employee_code)) = ?", normalized_code.downcase)
  end

  def current_user_quiz
    UserQuiz.find_by(id: session[quiz_session_key])
  end

  def current_quiz_submission
    authenticated_user_quiz = current_user_quiz
    return unless authenticated_user_quiz

    quiz_submission_for(authenticated_user_quiz)
  end

  def quiz_session_key
    "quiz_access_user_quiz_#{@quiz.id}"
  end

  def quiz_play_state_key
    "quiz_access_play_state_#{@quiz.id}"
  end

  def quiz_submission_for(user_quiz)
    return unless user_quiz

    normalized_code = user_quiz.employee_code.to_s.strip.downcase
    return if normalized_code.blank?

    submission = QuizSubmission.find_by("quiz_id = ? AND LOWER(TRIM(employee_code)) = ?", @quiz.id, normalized_code)
    return unless submission

    if accidental_blank_submission?(submission)
      recover_accidental_submission!(submission, user_quiz)
      return
    end

    submission
  end

  def build_quiz_submission(user_quiz)
    QuizSubmission.find_or_initialize_by(quiz: @quiz, employee_code: user_quiz.employee_code.to_s.strip).tap do |submission|
      submission.user_quiz = user_quiz
      submission.user = user_quiz.user
      submission.employee_detail = user_quiz.employee_detail_record
    end
  end

  def extract_answers
    params.fetch(:answers, {}).to_unsafe_h.transform_values(&:to_s)
  end

  def calculate_score(submitted_answers)
    @quiz.questions.count do |question|
      submitted_answers[question.id.to_s] == question.correct_answer.to_s
    end
  end

  def ensure_quiz_play_state!(user_quiz)
    state = session[quiz_play_state_key]
    return state if quiz_play_state_valid?(state, user_quiz)

    session[quiz_play_state_key] = build_quiz_play_state(user_quiz)
  end

  def quiz_play_state_valid?(state, user_quiz)
    return false unless state.is_a?(Hash)
    return false unless state["user_quiz_id"].to_i == user_quiz.id

    question_ids = Array(state["question_ids"]).map(&:to_i)
    current_question_ids = @quiz.questions.ids

    question_ids.present? &&
      question_ids.size == current_question_ids.size &&
      question_ids.sort == current_question_ids.sort
  end

  def build_quiz_play_state(user_quiz)
    question_ids = @quiz.questions.ids.shuffle
    media_files = @quiz.question_media_files.shuffle
    question_media = question_ids.each_with_index.each_with_object({}) do |(question_id, index), memo|
      memo[question_id.to_s] = media_files[index % media_files.length]
    end

    {
      "quiz_id" => @quiz.id,
      "user_quiz_id" => user_quiz.id,
      "started_at" => Time.current.iso8601,
      "question_ids" => question_ids,
      "question_media" => question_media
    }
  end

  def ordered_questions_for(state)
    questions_by_id = @quiz.questions.index_by(&:id)

    Array(state["question_ids"]).filter_map do |question_id|
      questions_by_id[question_id.to_i]
    end
  end

  def question_media_map_for(ordered_questions, state)
    saved_media = state.fetch("question_media", {})
    default_media = @quiz.question_media_files

    ordered_questions.each_with_index.each_with_object({}) do |(question, index), memo|
      memo[question.id] = saved_media[question.id.to_s].presence || default_media[index % default_media.length]
    end
  end

  def quiz_duration_seconds
    @quiz.duration_in_seconds
  end

  def quiz_started_at_for(state)
    raw_started_at = state["started_at"].presence
    return Time.current unless raw_started_at

    Time.zone.parse(raw_started_at) || Time.current
  rescue ArgumentError, TypeError
    Time.current
  end

  def quiz_seconds_remaining(started_at, duration_seconds)
    return 0 unless duration_seconds.to_i.positive?

    elapsed_seconds = [(Time.current - started_at).to_i, 0].max
    [duration_seconds - elapsed_seconds, 0].max
  end

  def complete_quiz_submission!(user_quiz, submitted_answers)
    score = calculate_score(submitted_answers)
    quiz_submission = build_quiz_submission(user_quiz)
    submitted_at = Time.current

    quiz_submission.assign_attributes(
      score: score,
      status: "completed",
      submitted_answers: submitted_answers,
      submitted_at: submitted_at
    )

    ActiveRecord::Base.transaction do
      user_quiz.update!(
        quiz: @quiz,
        score: score,
        status: "completed",
        submitted_answers: submitted_answers,
        submitted_at: submitted_at
      )

      quiz_submission.save!
    end

    clear_quiz_access_session!
    quiz_submission
  end

  def clear_quiz_access_session!
    session.delete(quiz_session_key)
    session.delete(quiz_play_state_key)
  end

  def accidental_blank_submission?(submission)
    submission.status.to_s == "completed" &&
      submission.score.to_i.zero? &&
      submission.submitted_answers.blank?
  end

  def recover_accidental_submission!(submission, user_quiz)
    ActiveRecord::Base.transaction do
      submission.destroy!

      user_quiz.update!(
        quiz: nil,
        score: nil,
        status: nil,
        submitted_answers: {},
        submitted_at: nil
      )
    end

    clear_quiz_access_session!
  end
end
