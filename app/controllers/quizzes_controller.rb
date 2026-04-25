require "roo"
require "axlsx"

class QuizzesController < ApplicationController
  before_action :authorize_hod!
  before_action :set_quiz, only: [ :show, :edit, :update, :destroy ]

  def index
    @quizzes = Quiz.includes(:questions).order(created_at: :desc)
  end

  def new
    @quiz = Quiz.new(status: "active")
    build_question_if_needed
  end

  def show
    @quiz.update_column(:qr_token, SecureRandom.urlsafe_base64(10)) if @quiz.qr_token.blank?
    @public_quiz_url = public_quiz_url_for(@quiz)
  end

  def create
    @quiz = Quiz.new(quiz_params)

    if @quiz.save
      redirect_to quiz_path(@quiz), notice: "Quiz created successfully. QR generated below."
    else
      build_question_if_needed
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    build_question_if_needed
  end

  def update
    if @quiz.update(quiz_params)
      redirect_to quiz_path(@quiz), notice: "Quiz updated successfully. QR refreshed below."
    else
      build_question_if_needed
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @quiz.destroy
    redirect_to quizzes_path, notice: "Quiz deleted successfully."
  end

  def import
    file = params[:file]

    unless valid_excel_file?(file)
      redirect_to quizzes_path, alert: "Please upload a valid .xlsx or .xls file."
      return
    end

    spreadsheet = Roo::Spreadsheet.open(file.path)
    headers = spreadsheet.row(1).map { |value| normalize_header(value) }

    if headers.compact_blank.empty? || spreadsheet.last_row.to_i < 2
      redirect_to quizzes_path, alert: "Excel file is empty."
      return
    end

    quiz = build_quiz_from_excel(spreadsheet, headers)

    if quiz.save
      redirect_to quiz_path(quiz), notice: "Quiz imported successfully. QR generated below."
    else
      redirect_to quizzes_path, alert: quiz.errors.full_messages.to_sentence.presence || "Quiz import failed."
    end
  end

  def export
    package = Axlsx::Package.new

    package.workbook.add_worksheet(name: "Quizzes") do |sheet|
      sheet.add_row [
        "Title",
        "Description",
        "Duration",
        "Status",
        "Question",
        "Option A",
        "Option B",
        "Option C",
        "Option D",
        "Correct Answer"
      ]

      Quiz.includes(:questions).order(created_at: :desc).find_each do |quiz|
        if quiz.questions.any?
          quiz.questions.order(:id).each_with_index do |question, index|
            sheet.add_row quiz_export_row(quiz, question, index + 1)
          end
        else
          sheet.add_row quiz_export_row(quiz, nil, nil)
        end
      end
    end

    tempfile = Tempfile.new([ "quizzes", ".xlsx" ])
    package.serialize(tempfile.path)

    send_file tempfile.path,
              filename: "quizzes_#{Date.current}.xlsx",
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
              disposition: "attachment"
  end

  def download_template
    package = Axlsx::Package.new

    package.workbook.add_worksheet(name: "Quiz Template") do |sheet|
      sheet.add_row [
        "Title",
        "Description",
        "Duration",
        "Status",
        "Question",
        "Option A",
        "Option B",
        "Option C",
        "Option D",
        "Correct Answer"
      ]

      sheet.add_row [
        "Capital of India",
        "Basic GK quiz",
        "5",
        "active",
        "India ki capital kya hai?",
        "Bhopal",
        "Delhi",
        "Mumbai",
        "Indore",
        "option_b"
      ]

      sheet.add_row [
        "Capital of India",
        "Basic GK quiz",
        "5",
        "active",
        "National animal kaun sa hai?",
        "Lion",
        "Tiger",
        "Elephant",
        "Cow",
        "option_b"
      ]
    end

    tempfile = Tempfile.new([ "quiz_template", ".xlsx" ])
    package.serialize(tempfile.path)

    send_file tempfile.path,
              filename: "quiz_template.xlsx",
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
              disposition: "attachment"
  end

  private

  def set_quiz
    @quiz = Quiz.find(params[:id])
  end

  def quiz_params
    params.require(:quiz).permit(
      :title,
      :description,
      :duration,
      :status,
      questions_attributes: [
        :id,
        :question,
        :option_a,
        :option_b,
        :option_c,
        :option_d,
        :correct_answer,
        :_destroy
      ]
    )
  end

  def build_question_if_needed
    @quiz.questions.build if @quiz.questions.empty?
  end

  def valid_excel_file?(file)
    file.present? && [ ".xlsx", ".xls" ].include?(File.extname(file.original_filename).downcase)
  end

  def build_quiz_from_excel(spreadsheet, headers)
    first_row = row_to_attributes(headers, spreadsheet.row(2))
    quiz = Quiz.new(
      title: first_row["title"],
      description: first_row["description"],
      duration: first_row["duration"],
      status: normalized_status(first_row["status"])
    )

    (2..spreadsheet.last_row).each do |row_number|
      values = spreadsheet.row(row_number)
      next if values.compact_blank.empty?

      row = row_to_attributes(headers, values)

      option_a = row["option_a"]
      option_b = row["option_b"]
      option_c = row["option_c"]
      option_d = row["option_d"]

      quiz.questions.build(
        question: row["question"],
        option_a: option_a,
        option_b: option_b,
        option_c: option_c,
        option_d: option_d,
        correct_answer: normalized_correct_answer(row["correct_answer"], option_a:, option_b:, option_c:, option_d:)
      )
    end

    quiz
  end

  def row_to_attributes(headers, values)
    Hash[headers.zip(values.map { |value| value.to_s.strip })]
  end

  def normalize_header(value)
    value.to_s.strip.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/\A_+|_+\z/, "")
  end

  def normalized_status(raw_status)
    value = raw_status.to_s.strip.downcase
    %w[active inactive].include?(value) ? value : "active"
  end

  def normalized_correct_answer(raw_answer, option_a:, option_b:, option_c:, option_d:)
    original_value = raw_answer.to_s.strip
    value = original_value.downcase.gsub(/[\s\-]+/, "_")
    return value if %w[option_a option_b option_c option_d].include?(value)

    mapping = {
      "a" => "option_a",
      "b" => "option_b",
      "c" => "option_c",
      "d" => "option_d",
      "1" => "option_a",
      "2" => "option_b",
      "3" => "option_c",
      "4" => "option_d",
      "option1" => "option_a",
      "option2" => "option_b",
      "option3" => "option_c",
      "option4" => "option_d",
      "option_1" => "option_a",
      "option_2" => "option_b",
      "option_3" => "option_c",
      "option_4" => "option_d"
    }

    mapped_value = mapping[value]
    return mapped_value if mapped_value.present?

    option_map = {
      option_a.to_s.strip.downcase => "option_a",
      option_b.to_s.strip.downcase => "option_b",
      option_c.to_s.strip.downcase => "option_c",
      option_d.to_s.strip.downcase => "option_d"
    }.reject { |key, _| key.blank? }

    option_map[original_value.downcase]
  end

  def quiz_export_row(quiz, question, question_number)
    [
      quiz.title,
      quiz.description,
      quiz.duration,
      quiz.status,
      question&.question,
      question&.option_a,
      question&.option_b,
      question&.option_c,
      question&.option_d,
      question&.correct_answer
    ]
  end

  def authorize_hod!
    return if current_user.hod?

    redirect_to settings_path, alert: "You are not authorized to access this page."
  end

  def public_quiz_url_for(quiz)
    "#{request.base_url}#{quiz_access_path(quiz.qr_token)}"
  end
end
