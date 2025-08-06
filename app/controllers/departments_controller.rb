require 'roo'

class DepartmentsController < ApplicationController
  before_action :set_department, only: [:show, :edit, :update, :destroy, :edit_data]
  
  def index
    @departments = Department.includes(:activities).all
    @employee_departments = EmployeeDetail.distinct.pluck(:department).compact
    @department = Department.new
    3.times { @department.activities.build }
    
    respond_to do |format|
      format.html
      format.json do
        render json: @departments.as_json(include: {
          activities: {
            only: [:id, :activity_id, :activity_name, :unit, :weight]
          }
          }, only: [:id, :department_type, :theme_id, :theme_name])
        end
      end
    end
    
  def new
      @department = Department.new
      @employee_departments = EmployeeDetail.distinct.pluck(:department).compact
    3.times { @department.activities.build }
  end
  

  def create
    @department = Department.new(department_params)

    if @department.save
      redirect_to departments_path, notice: 'Department was successfully created.'
    else
      @departments = Department.includes(:activities).all
      flash.now[:alert] = "Failed to create department: #{@department.errors.full_messages.join(', ')}"
      render :index, status: :unprocessable_entity
    end
  end

  def edit
    @department = Department.find(params[:id])
  end

  def edit_data
    render json: {
      id: @department.id,
      department_type: @department.department_type,
      theme_id: @department.theme_id,
      theme_name: @department.theme_name,
      activities: @department.activities.map do |activity|
        {
          id: activity.id,
          activity_name: activity.activity_name,
          unit: activity.unit,
          weight: activity.weight
        }
      end
    }
  end
  

  def update
    if @department.update(department_params)
      respond_to do |format|
        format.html { redirect_to departments_path, notice: 'Department was successfully updated.' }
        format.json { render json: { success: true, message: 'Department updated successfully!' } }
      end
    else
      respond_to do |format|
        format.html { 
          @employee_departments = EmployeeDetail.distinct.pluck(:department).compact
          render :edit, status: :unprocessable_entity 
        }
        format.json { render json: { success: false, errors: @department.errors.full_messages } }
      end
    end
  end

  def import
    file = params[:file]

    if file.nil?
      redirect_to departments_path, alert: 'Please upload a file.'
      return
    end

    spreadsheet = Roo::Spreadsheet.open(file.path)
    header = spreadsheet.row(1)

    # Correct header mapping — match the exported file!
    header_map = {
      "Department" => "department_type",
      "Theme" => "theme_name",
      "Activity ID" => "activity_id",
      "Activity Name" => "activity_name",
      "Unit" => "unit",
      "Weight" => "weight"
    }

    departments_hash = {}

    (2..spreadsheet.last_row).each do |i|
      row_data = spreadsheet.row(i)
      row = Hash[[header, row_data].transpose]
      mapped = row.transform_keys { |key| header_map[key] }.compact

      next if mapped["department_type"].blank? || mapped["theme_name"].blank?

      key = "#{mapped["department_type"]}-#{mapped["theme_name"]}"
      departments_hash[key] ||= { department_type: mapped["department_type"], theme_name: mapped["theme_name"], activities: [] }

      departments_hash[key][:activities] << {
        activity_id: mapped["activity_id"],
        activity_name: mapped["activity_name"],
        unit: mapped["unit"],
        weight: mapped["weight"]
      }
    end

    # Create departments and activities
    departments_hash.each_value do |dept_data|
      department = Department.create!(
        department_type: dept_data[:department_type],
        theme_name: dept_data[:theme_name]
      )

      dept_data[:activities].each do |act|
        department.activities.create!(act)
      end
    end

    redirect_to departments_path, notice: "✅ Departments and activities imported successfully!"
  rescue => e
    redirect_to departments_path, alert: "❌ Import failed: #{e.message}"
  end


  def export
    @departments = Department.includes(:activities)

    respond_to do |format|
      format.xlsx {
        response.headers['Content-Disposition'] = 'attachment; filename="departments_export.xlsx"'
        render xlsx: 'export', template: 'departments/export'
      }
    end
  end

  def destroy
    @department.destroy
    redirect_to departments_path, notice: 'Department was successfully deleted.'
  end

  private

  def set_department
    @department = Department.find(params[:id])
  end

  def department_params
    params.require(:department).permit(:department_type, :theme_id, :theme_name, 
    activities_attributes: [:id, :activity_id, :activity_name, :unit, :weight, :_destroy])
  end
end