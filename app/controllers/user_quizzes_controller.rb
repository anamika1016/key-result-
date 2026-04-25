require "roo"
require "axlsx"

class UserQuizzesController < ApplicationController
  before_action :authorize_hod!

  HEADER_MAP = {
    "employee code" => "employee_code",
    "name" => "name",
    "email" => "email",
    "mobile number" => "mobile_number",
    "designation" => "designation",
    "branch" => "branch",
    "sub branch" => "sub_branch",
    "password" => "password"
  }.freeze

  def index
    @user_quiz = UserQuiz.new
    @query = params[:query].to_s.strip
    @user_quizzes = filtered_user_quizzes.page(params[:page]).per(10)
    @quiz_submissions = QuizSubmission.includes(:quiz, :user_quiz).recent_first.limit(50)
  end

  def create
    attributes = user_quiz_params.to_h
    employee_code = attributes["employee_code"].to_s.strip
    @user_quiz = employee_code.present? ? UserQuiz.find_or_initialize_by(employee_code: employee_code) : UserQuiz.new
    @user_quiz.assign_attributes(attributes)

    if @user_quiz.save
      redirect_to user_quizzes_path, notice: @user_quiz.previously_new_record? ? "User quiz record created successfully." : "User quiz record updated successfully."
    else
      @query = params[:query].to_s.strip
      @user_quizzes = filtered_user_quizzes.page(params[:page]).per(10)
      @quiz_submissions = QuizSubmission.includes(:quiz, :user_quiz).recent_first.limit(50)
      flash.now[:alert] = @user_quiz.errors.full_messages.to_sentence
      render :index, status: :unprocessable_entity
    end
  end

  def export
    package = Axlsx::Package.new

    package.workbook.add_worksheet(name: "User Quiz Entries") do |sheet|
      sheet.add_row [
        "Employee Code",
        "Name",
        "Email",
        "Mobile Number",
        "Designation",
        "Branch",
        "Sub Branch",
        "Quiz",
        "Score",
        "Status",
        "Submitted At"
      ]

      UserQuiz.includes(:user, :quiz).recent_first.find_each do |user_quiz|
        sheet.add_row [
          user_quiz.employee_code,
          user_quiz.name,
          user_quiz.email,
          user_quiz.mobile_number,
          user_quiz.designation,
          user_quiz.branch,
          user_quiz.sub_branch,
          user_quiz.quiz&.title,
          user_quiz.score,
          user_quiz.status,
          user_quiz.submitted_at&.strftime("%d %b %Y %I:%M %p")
        ]
      end
    end

    package.workbook.add_worksheet(name: "Completed Quiz History") do |sheet|
      sheet.add_row [
        "Quiz",
        "Employee Code",
        "Name",
        "Email",
        "Mobile Number",
        "Designation",
        "Branch",
        "Sub Branch",
        "Score",
        "Total Questions",
        "Status",
        "Submitted At"
      ]

      QuizSubmission.includes(quiz: :questions).recent_first.find_each do |submission|
        sheet.add_row [
          submission.quiz&.title,
          submission.employee_code,
          submission.name,
          submission.email,
          submission.mobile_number,
          submission.designation,
          submission.branch,
          submission.sub_branch,
          submission.score,
          submission.quiz&.questions&.count.to_i,
          submission.status,
          submission.submitted_at&.strftime("%d %b %Y %I:%M %p")
        ]
      end
    end

    tempfile = Tempfile.new([ "user_quiz_entries", ".xlsx" ])
    package.serialize(tempfile.path)

    send_file tempfile.path,
              filename: "user_quiz_entries_#{Date.current}.xlsx",
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
              disposition: "attachment"
  end

  def import
    file = params[:file]

    unless valid_excel_file?(file)
      redirect_to user_quizzes_path, alert: "Please upload a valid .xlsx or .xls file."
      return
    end

    spreadsheet = Roo::Spreadsheet.open(file.path)
    header = spreadsheet.row(1).map { |value| normalize_header(value) }

    imported_count = 0
    updated_count = 0
    errors = []

    (2..spreadsheet.last_row).each do |row_number|
      row_values = spreadsheet.row(row_number)
      next if row_values.compact_blank.empty?

      raw_row = Hash[header.zip(row_values)]
      mapped_attributes = map_import_row(raw_row)

      if mapped_attributes["employee_code"].blank?
        errors << "Row #{row_number}: Employee Code is required."
        next
      end

      user_quiz = UserQuiz.find_or_initialize_by(employee_code: mapped_attributes["employee_code"].to_s.strip)
      user_quiz.assign_attributes(mapped_attributes)

      if user_quiz.save
        user_quiz.previously_new_record? ? imported_count += 1 : updated_count += 1
      else
        errors << "Row #{row_number}: #{user_quiz.errors.full_messages.to_sentence}"
      end
    end

    if errors.any?
      redirect_to user_quizzes_path, alert: "Imported with some issues. Added: #{imported_count}, Updated: #{updated_count}. #{errors.first(5).join(' ')}"
    else
      redirect_to user_quizzes_path, notice: "Excel imported successfully. Added: #{imported_count}, Updated: #{updated_count}."
    end
  end

  def download_template
    package = Axlsx::Package.new

    package.workbook.add_worksheet(name: "User Quiz Template") do |sheet|
      sheet.add_row [
        "Employee Code",
        "Name",
        "Email",
        "Mobile Number",
        "Designation",
        "Branch",
        "Sub Branch",
        "Password"
      ]
    end

    tempfile = Tempfile.new([ "user_quiz_template", ".xlsx" ])
    package.serialize(tempfile.path)

    send_file tempfile.path,
              filename: "user_quiz_template.xlsx",
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
              disposition: "attachment"
  end

  private

  def user_quiz_params
    params.require(:user_quiz).permit(*UserQuiz::IMPORTABLE_FIELDS)
  end

  def authorize_hod!
    return if current_user.hod?

    redirect_to settings_path, alert: "You are not authorized to access this page."
  end

  def valid_excel_file?(file)
    file.present? && [ ".xlsx", ".xls" ].include?(File.extname(file.original_filename).downcase)
  end

  def normalize_header(value)
    value.to_s.strip.downcase.gsub(/[_\s]+/, " ")
  end

  def map_import_row(raw_row)
    raw_row.each_with_object({}) do |(header, value), attributes|
      field = HEADER_MAP[header]
      next if field.blank?

      attributes[field] = value
    end
  end

  def filtered_user_quizzes
    scope = UserQuiz.includes(:user, :quiz).recent_first
    return scope if @query.blank?

    q = "%#{@query.downcase}%"
    scope.where(
      "LOWER(COALESCE(employee_code, '')) LIKE :q OR LOWER(COALESCE(name, '')) LIKE :q OR LOWER(COALESCE(email, '')) LIKE :q OR LOWER(COALESCE(mobile_number, '')) LIKE :q OR LOWER(COALESCE(branch, '')) LIKE :q OR LOWER(COALESCE(sub_branch, '')) LIKE :q",
      q: q
    )
  end
end
