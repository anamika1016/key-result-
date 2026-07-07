require "roo"
require "zip"

class EmployeeTrainingsController < ApplicationController
  before_action :authenticate_user!
  before_action :load_form_options, only: [ :new, :create ]
  before_action :set_employee_training, only: [ :show, :destroy ]
  before_action :ensure_hod_for_destroy!, only: [ :destroy ]
  before_action :require_training_master_admin!, only: [
    :master_data,
    :create_master_project,
    :create_master_office,
    :destroy_master_projects,
    :destroy_master_offices,
    :import_master_data,
    :download_master_template
  ]

  def index
    @employee_trainings = EmployeeTraining
      .includes(training_register_attachment: :blob, photo_upload_attachment: :blob)
      .recent_first
  end

  def new
    @employee_training = EmployeeTraining.new
  end

  def show
    @selected_employees = @employee_training.selected_employees
  end

  def destroy
    @employee_training.destroy
    redirect_to employee_trainings_path, notice: "Training record deleted successfully."
  end

  def create
    @employee_training = current_user.employee_trainings.new(employee_training_attributes)

    if @employee_training.save
      redirect_to @employee_training, notice: "Employee training details saved successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def master_data
    @employee_training_projects = EmployeeTrainingProject.ordered
    @employee_training_offices = EmployeeTrainingOffice.ordered
  end

  def import_master_data
    file = params[:file]
    master_type = params[:master_type].to_s

    unless valid_master_upload_file?(file)
      redirect_to master_data_employee_trainings_path, alert: "Please upload a valid .xlsx or .xls file."
      return
    end

    result = case master_type
             when "project"
               import_training_project_file(file)
             when "office_fpo"
               import_training_office_file(file)
             else
               { errors: [ "select project or office/FPO upload type" ] }
             end

    message = import_result_message(master_type, result)

    if result[:errors].present?
      redirect_to master_data_employee_trainings_path, alert: "#{message}. Skipped rows: #{result[:errors].join(', ')}"
    else
      redirect_to master_data_employee_trainings_path, notice: "#{message}."
    end
  rescue Roo::FileNotFound, ArgumentError, Zip::Error => e
    redirect_to master_data_employee_trainings_path, alert: "Excel file could not be read: #{e.message}"
  end

  def download_master_template
    respond_to do |format|
      format.xlsx do
        response.headers["Content-Disposition"] = 'attachment; filename="training_master_template.xlsx"'
      end
    end
  end

  def create_master_project
    project_name = params[:project_name].to_s.strip

    if project_name.blank?
      redirect_to master_data_employee_trainings_path, alert: "Project Name is required."
      return
    end

    project = find_training_project(project_name)
    action = project.new_record? ? "added" : "updated"
    project.update!(name: project_name, active: true)

    redirect_to master_data_employee_trainings_path, notice: "Project #{action} successfully."
  end

  def create_master_office
    office_type = params[:office_type].to_s.strip
    office_name = params[:office_name].to_s.strip
    fpo_name = params[:fpo_name].to_s.strip

    if office_type.blank? || (office_name.blank? && fpo_name.blank?)
      redirect_to master_data_employee_trainings_path, alert: "Office Type and Office Name or FPO are required."
      return
    end

    office = find_training_office(office_type, office_name, fpo_name)
    action = office.new_record? ? "added" : "updated"
    office.update!(office_type: office_type, office_name: office_name, fpo_name: fpo_name, active: true)

    redirect_to master_data_employee_trainings_path, notice: "Office/FPO row #{action} successfully."
  end

  def destroy_master_projects
    project_ids = Array(params[:project_ids]).reject(&:blank?)

    if project_ids.blank?
      redirect_to master_data_employee_trainings_path, alert: "Select at least one project to delete."
      return
    end

    deleted_count = EmployeeTrainingProject.where(id: project_ids).destroy_all.size
    redirect_to master_data_employee_trainings_path, notice: "#{deleted_count} project(s) deleted successfully."
  end

  def destroy_master_offices
    office_ids = Array(params[:office_ids]).reject(&:blank?)

    if office_ids.blank?
      redirect_to master_data_employee_trainings_path, alert: "Select at least one Office/FPO row to delete."
      return
    end

    deleted_count = EmployeeTrainingOffice.where(id: office_ids).destroy_all.size
    redirect_to master_data_employee_trainings_path, notice: "#{deleted_count} Office/FPO row(s) deleted successfully."
  end

  private

  def set_employee_training
    @employee_training = EmployeeTraining.find(params[:id])
  end

  def ensure_hod_for_destroy!
    redirect_to employee_trainings_path, alert: "Only HOD admin can delete training records." unless current_user.hod?
  end

  def employee_training_attributes
    {
      project_name: params[:project_name],
      office_types: Array(params[:office_type]),
      office_names: Array(params[:office_name]),
      fpo_names: Array(params[:fpo_name]),
      thematic_department_name: params[:thematic_department_name],
      training_date: params[:training_date],
      topic: params[:topic],
      other_topic: params[:other_topic],
      details: params[:details],
      training_location: params[:training_location],
      asa_participants: params[:asa_participants],
      other_participants: params[:other_participants],
      qr_id: params[:qr_id],
      employee_detail_ids: Array(params[:employee_ids]),
      training_register: params[:training_register],
      photo_upload: params[:photo_upload]
    }
  end

  def load_form_options
    @project_name_options = EmployeeTrainingProject.table_exists? ? EmployeeTrainingProject.option_names : []

    office_option_groups = EmployeeTrainingOffice.table_exists? ? EmployeeTrainingOffice.option_groups : {}

    @office_options_by_type = office_option_groups.transform_values { |values| values[:offices].sort }
    @fpo_options_by_type = office_option_groups.transform_values { |values| values[:fpos].sort }
    @fpo_options_by_office = office_option_groups.transform_values do |values|
      values[:fpos_by_office].transform_values(&:sort)
    end
    @office_type_options = office_option_groups.keys.sort
    @office_options = @office_options_by_type.values.flatten.uniq.sort
    @fpo_options = @fpo_options_by_type.values.flatten.uniq.sort

    @thematic_department_options = EmployeeTrainingThematic.active.ordered.map(&:display_name)

    @topics_by_thematic_department = EmployeeTrainingTopic
      .active
      .ordered
      .pluck(:thematic_department_name, :name)
      .each_with_object({}) do |(thematic_department_name, topic_name), grouped|
        thematic_department_name = thematic_department_name.to_s.strip
        topic_name = topic_name.to_s.strip
        next if thematic_department_name.blank? || topic_name.blank?

        grouped[thematic_department_name] ||= []
        grouped[thematic_department_name] << topic_name unless grouped[thematic_department_name].include?(topic_name)
      end

    @employees = EmployeeDetail
      .where.not(employee_code: [ nil, "" ])
      .order(:employee_code)
      .select(:id, :employee_code, :employee_name)
  end

  def require_training_master_admin!
    redirect_to new_employee_training_path, alert: "You are not authorized to manage training master data." unless current_user.hod?
  end

  def valid_master_upload_file?(file)
    file.present? && [ ".xlsx", ".xls" ].include?(File.extname(file.original_filename).downcase)
  end

  def import_training_project_file(file)
    workbook = Roo::Spreadsheet.open(file.path)
    sheet = training_master_sheet(workbook, "Projects")
    headers = normalized_headers(sheet.row(1))
    result = Hash.new(0)
    result[:errors] = []

    ActiveRecord::Base.transaction do
      (2..sheet.last_row).each do |row_number|
        row = sheet.row(row_number)
        project_name = master_cell(row, headers, "project_name", "project").presence

        if project_name.blank?
          result[:errors] << "row #{row_number}"
          next
        end

        project = find_training_project(project_name)
        project.new_record? ? result[:projects_created] += 1 : result[:projects_updated] += 1
        project.update!(name: project_name, active: true)
      end
    end

    result
  end

  def import_training_office_file(file)
    workbook = Roo::Spreadsheet.open(file.path)
    sheet = training_master_sheet(workbook, "Office FPO")
    headers = normalized_headers(sheet.row(1))
    result = Hash.new(0)
    result[:errors] = []

    ActiveRecord::Base.transaction do
      (2..sheet.last_row).each do |row_number|
        row = sheet.row(row_number)
        office_type = master_cell(row, headers, "office_type", "ofc_type").presence
        office_name = master_cell(row, headers, "office_name", "office").presence
        fpo_name = master_cell(row, headers, "fpo_name", "fpo").presence

        next if [ office_type, office_name, fpo_name ].all?(&:blank?)

        if office_type.blank? || (office_name.blank? && fpo_name.blank?)
          result[:errors] << "row #{row_number}"
          next
        end

        office = find_training_office(office_type, office_name, fpo_name)
        office.new_record? ? result[:offices_created] += 1 : result[:offices_updated] += 1
        office.update!(office_type: office_type, office_name: office_name, fpo_name: fpo_name, active: true)
      end
    end

    result
  end

  def import_result_message(master_type, result)
    case master_type
    when "project"
      "#{result[:projects_created]} projects added, #{result[:projects_updated]} projects updated"
    when "office_fpo"
      "#{result[:offices_created]} office/FPO rows added, #{result[:offices_updated]} office/FPO rows updated"
    else
      "Upload type missing"
    end
  end

  def normalized_headers(header_row)
    header_row.each_with_index.with_object({}) do |(header, index), headers|
      normalized = header.to_s.strip.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/\A_|_\z/, "")
      headers[normalized] = index if normalized.present?
    end
  end

  def training_master_sheet(workbook, preferred_name)
    workbook.sheets.include?(preferred_name) ? workbook.sheet(preferred_name) : workbook.sheet(0)
  end

  def master_cell(row, headers, *keys)
    index = keys.lazy.map { |key| headers[key] }.find(&:present?)
    return nil if index.nil?

    row[index].to_s.strip
  end

  def find_training_project(project_name)
    EmployeeTrainingProject.where("LOWER(name) = ?", project_name.downcase).first || EmployeeTrainingProject.new
  end

  def find_training_office(office_type, office_name, fpo_name)
    EmployeeTrainingOffice
      .where("LOWER(office_type) = ?", office_type.downcase)
      .where("LOWER(COALESCE(office_name, '')) = ?", office_name.to_s.downcase)
      .where("LOWER(COALESCE(fpo_name, '')) = ?", fpo_name.to_s.downcase)
      .first || EmployeeTrainingOffice.new
  end
end
