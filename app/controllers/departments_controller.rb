require 'roo'

class DepartmentsController < ApplicationController
  before_action :set_department, only: [:show, :edit, :update, :destroy, :edit_data]
  
  def index
    @departments = Department.includes(:activities).all
    @employee_departments = EmployeeDetail.distinct.pluck(:department).compact.reject(&:blank?)
    @employees = EmployeeDetail.where.not(employee_name: nil, employee_id: nil, department: nil)
                              .select(:employee_name, :employee_id, :department)
                              .order(:employee_name)
    @department = Department.new
    3.times { @department.activities.build }
    
    # Debug: Log the data structure
    Rails.logger.debug "Departments loaded: #{@departments.count}"
    @departments.each do |dept|
      Rails.logger.debug "Department #{dept.id}: #{dept.department_type} - Employee: #{dept.employee_reference} - Activities: #{dept.activities.count}"
    end
    
    respond_to do |format|
      format.html
      format.json do
        render json: @departments.as_json(include: {
          activities: {
            only: [:id, :theme_name, :activity_name, :unit, :weight]
          }
          }, methods: [:employee_name, :employee_code, :employee_display_name], only: [:id, :department_type, :theme_name, :employee_reference])
        end
      end
  end
    
  def new
    @department = Department.new
    @employee_departments = EmployeeDetail.distinct.pluck(:department).compact.reject(&:blank?)
    @employees = EmployeeDetail.where.not(employee_name: nil, employee_id: nil, department: nil)
                              .select(:employee_name, :employee_id, :department)
                              .order(:employee_name)
    3.times { @department.activities.build }
  end
  
  def create
    @department = Department.new(department_params)

    respond_to do |format|
      if @department.save
        format.html { redirect_to departments_path, notice: 'Department was successfully created.' }
        format.json { render json: { success: true, message: 'Department created successfully!' } }
      else
        format.html { 
          @departments = Department.includes(:activities).all
          @employees = EmployeeDetail.select(:employee_name, :employee_id, :department).distinct.compact
          flash.now[:alert] = "Failed to create department: #{@department.errors.full_messages.join(', ')}"
          render :index, status: :unprocessable_entity 
        }
        format.json { render json: { success: false, errors: @department.errors.full_messages } }
      end
    end
  end

  def edit
    @department = Department.find(params[:id])
    @employee_departments = EmployeeDetail.distinct.pluck(:department).compact
    @employees = EmployeeDetail.select(:employee_name, :employee_id, :department).distinct.compact
  end

  def edit_data
    # Get employee name from EmployeeDetail using employee_reference
    employee = EmployeeDetail.find_by(employee_id: @department.employee_reference)
    employee_name = employee&.employee_name
    employee_code = employee&.employee_code
    
    render json: {
      id: @department.id,
      department_type: @department.department_type,
      theme_name: @department.theme_name,
      employee_reference: @department.employee_reference,
      employee_name: employee_name,
      employee_code: employee_code,
      employee_display_name: employee ? "#{employee_name} (#{employee_code})" : 'N/A',
      activities: @department.activities.map do |activity|
        {
          id: activity.id,
          theme_name: activity.theme_name,
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
          @employees = EmployeeDetail.select(:employee_name, :employee_id, :department).distinct.compact
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

    header_map = {
      "Department" => "department_type",
      "Employee Name" => "employee_name",
      "Theme Name" => "theme_name",
      "Activity Name" => "activity_name",
      "Unit" => "unit",
      "Weight" => "weight"
    }

    departments_hash = {}
    import_errors = []
    success_count = 0

    (2..spreadsheet.last_row).each do |i|
      row_data = spreadsheet.row(i)
      row = Hash[[header, row_data].transpose]
      mapped = row.transform_keys { |key| header_map[key] }.compact

      # Skip empty rows
      next if mapped["department_type"].blank? && mapped["employee_name"].blank? && mapped["theme_name"].blank?

      # Validate required fields
      if mapped["department_type"].blank?
        import_errors << "Row #{i}: Department is required"
        next
      end
      
      if mapped["employee_name"].blank?
        import_errors << "Row #{i}: Employee Name is required"
        next
      end

      if mapped["theme_name"].blank?
        import_errors << "Row #{i}: Theme Name is required"
        next
      end

      # Find employee reference by employee name
      employee = EmployeeDetail.find_by(employee_name: mapped["employee_name"])
      if employee.nil?
        import_errors << "Row #{i}: Employee '#{mapped["employee_name"]}' not found in system"
        next
      end

      # Create unique key for each department-employee-theme combination
      key = "#{mapped["department_type"]}-#{employee.employee_id}-#{mapped["theme_name"]}"
      departments_hash[key] ||= { 
        department_type: mapped["department_type"], 
        employee_reference: employee.employee_id,
        theme_name: mapped["theme_name"], 
        activities: [] 
      }

      # Only add activity if activity data is present
      if mapped["activity_name"].present?
        departments_hash[key][:activities] << {
          theme_name: mapped["theme_name"],
          activity_name: mapped["activity_name"],
          unit: mapped["unit"],
          weight: mapped["weight"]
        }
      end
    end

    if import_errors.any?
      redirect_to departments_path, alert: "❌ Import failed: #{import_errors.join(', ')}"
      return
    end

    # Create departments and activities
    ActiveRecord::Base.transaction do
      departments_hash.each_value do |dept_data|
        department = Department.create!(
          department_type: dept_data[:department_type],
          employee_reference: dept_data[:employee_reference],
          theme_name: dept_data[:theme_name]
        )

        dept_data[:activities].each do |act|
          department.activities.create!(act)
        end
        
        success_count += 1
      end
    end

    redirect_to departments_path, notice: "✅ Successfully imported #{success_count} department(s) with activities!"
  rescue => e
    redirect_to departments_path, alert: "❌ Import failed: #{e.message}"
  end

  def export
    @departments = Department.includes(:activities).all

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

  # Debug method to show current data structure
  def debug_data
    @departments = Department.includes(:activities).all
    @employee_details = EmployeeDetail.all
    
    render json: {
      departments: @departments.map do |dept|
        {
          id: dept.id,
          department_type: dept.department_type,
          theme_name: dept.theme_name,
          employee_reference: dept.employee_reference,
          employee_name: dept.employee_name,
          activities_count: dept.activities.count,
          activities: dept.activities.map do |act|
            {
              id: act.id,
              theme_name: act.theme_name,
              activity_name: act.activity_name,
              unit: act.unit,
              weight: act.weight
            }
          end
        }
      end,
      employee_details: @employee_details.map do |emp|
        {
          id: emp.id,
          employee_id: emp.employee_id,
          employee_name: emp.employee_name,
          employee_code: emp.employee_code,
          department: emp.department
        }
      end
    }
  end

  private

  def set_department
    @department = Department.find(params[:id])
  end

  def department_params
    params.require(:department).permit(:department_type, :employee_reference, :theme_name,
    activities_attributes: [:id, :theme_name, :activity_name, :unit, :weight, :_destroy])
  end
end