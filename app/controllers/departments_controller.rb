require 'roo'

class DepartmentsController < ApplicationController
  before_action :set_department, only: [:show, :edit, :update, :destroy, :edit_data]
  
  def index
    # Get all employees with their departments
    @employee_departments = EmployeeDetail.distinct.pluck(:department).compact.reject(&:blank?)
    @employees = EmployeeDetail.where.not(employee_name: nil, employee_id: nil, department: nil)
                              .select(:employee_name, :employee_id, :department)
                              .order(:employee_name)
    
    # Filter by employee if specified
    if params[:employee_id].present?
      @selected_employee = EmployeeDetail.find_by(employee_id: params[:employee_id])
      if @selected_employee
        # Get activities for the selected employee using UserDetail
        @employee_activities = get_employee_activities(@selected_employee)
      else
        @employee_activities = {}
      end
    elsif params[:employee_code].present?
      @selected_employee = EmployeeDetail.find_by(employee_code: params[:employee_code])
      if @selected_employee
        # Get activities for the selected employee using UserDetail
        @employee_activities = get_employee_activities(@selected_employee)
      else
        @employee_activities = {}
      end
    else
      # Show all employees with their activities grouped by employee
      @employee_activities = get_all_employee_activities
    end
    
    # Debug logging
    Rails.logger.info "Employee activities loaded: #{@employee_activities.count} employees"
    @employee_activities.each do |key, data|
      Rails.logger.info "Employee #{data[:employee_name]} (#{data[:employee_id]}): #{data[:total_activities]} activities"
      if data[:activities].any?
        data[:activities].each_with_index do |activity, index|
          Rails.logger.info "  Activity #{index + 1}: #{activity[:theme_name]} - #{activity[:activity_name]}"
        end
      end
    end
    
    @department = Department.new
    # Only build one activity by default to prevent duplicates
    @department.activities.build
    
    respond_to do |format|
      format.html
      format.json do
        render json: @employee_activities.values
      end
    end
  end
    
  def new
    @department = Department.new
    @employee_departments = EmployeeDetail.distinct.pluck(:department).compact.reject(&:blank?)
    @employees = EmployeeDetail.where.not(employee_name: nil, employee_id: nil, department: nil)
                              .select(:employee_name, :employee_id, :department)
                              .order(:employee_name)
    # Only build one activity by default to prevent duplicates
    @department.activities.build
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

  def update_employee_activities
    Rails.logger.info "=== update_employee_activities method called ==="
    Rails.logger.info "Request method: #{request.method}"
    Rails.logger.info "Request path: #{request.path}"
    Rails.logger.info "Request headers: #{request.headers.to_h.select { |k, v| k.start_with?('HTTP_') }}"
    
    employee_id = params[:employee_id]
    
    Rails.logger.info "Updating activities for employee: #{employee_id}"
    Rails.logger.info "Received params: #{params.inspect}"
    
    # Find all departments for this employee
    departments = Department.where(employee_reference: employee_id)
    Rails.logger.info "Found #{departments.count} departments for employee #{employee_id}"
    
    if departments.any?
      begin
        ActiveRecord::Base.transaction do
          # Update each department's activities
          departments.each do |dept|
            Rails.logger.info "Processing department #{dept.id} with #{dept.activities.count} existing activities"
            
                                      if params[:activities].present?
               Rails.logger.info "Processing #{params[:activities].count} activities for update"
               
               # Get existing activity IDs for this department
               existing_activity_ids = dept.activities.pluck(:id)
               Rails.logger.info "Existing activity IDs: #{existing_activity_ids}"
               
               # Find activities that are no longer in the form (deleted by user)
               # We'll need to check by content since the form doesn't send IDs for new activities
               activities_to_delete = []
               
               dept.activities.each do |existing_activity|
                 # Check if this activity still exists in the form data
                 activity_still_exists = params[:activities].any? do |form_activity|
                   form_activity[:theme_name] == existing_activity.theme_name &&
                   form_activity[:activity_name] == existing_activity.activity_name &&
                   form_activity[:unit] == existing_activity.unit &&
                   form_activity[:weight].to_s == existing_activity.weight.to_s
                 end
                 
                 unless activity_still_exists
                   activities_to_delete << existing_activity
                   Rails.logger.info "Activity #{existing_activity.id} (#{existing_activity.activity_name}) will be deleted"
                 end
               end
               
               # Delete only the activities that were removed from the form
               activities_to_delete.each do |activity|
                 Rails.logger.info "Deleting activity #{activity.id} (#{activity.activity_name})"
                 
                 # Delete user_details that reference this activity
                 user_details = UserDetail.where(activity_id: activity.id)
                 user_details_count = user_details.count
                 Rails.logger.info "Found #{user_details_count} user_details for activity #{activity.id}"
                 
                 # Delete the user_details (achievements and achievement_remarks will be deleted automatically)
                 user_details.destroy_all
                 Rails.logger.info "Deleted #{user_details_count} user_details for activity #{activity.id}"
                 
                 # Delete the activity
                 activity.destroy
                 Rails.logger.info "Deleted activity #{activity.id}"
               end
               
               # Now handle updates and new activities
               params[:activities].each_with_index do |activity_params, index|
                 Rails.logger.info "Processing activity #{index + 1}: #{activity_params.inspect}"
                 
                 # Try to find an existing activity to update
                 existing_activity = dept.activities.find_by(
                   theme_name: activity_params[:theme_name],
                   activity_name: activity_params[:activity_name]
                 )
                 
                 if existing_activity
                   # Update existing activity
                   Rails.logger.info "Updating existing activity #{existing_activity.id}"
                   existing_activity.update!(
                     unit: activity_params[:unit],
                     weight: activity_params[:weight]
                   )
                 else
                   # Create new activity
                   Rails.logger.info "Creating new activity"
                   dept.activities.create!(
                     theme_name: activity_params[:theme_name],
                     activity_name: activity_params[:activity_name],
                     unit: activity_params[:unit],
                     weight: activity_params[:weight]
                   )
                 end
               end
               
               Rails.logger.info "Updated department #{dept.id}: deleted #{activities_to_delete.count} activities, processed #{params[:activities].count} activities"
             end
          end
        end
        
        render json: { success: true, message: 'Employee activities updated successfully!' }
      rescue => e
        Rails.logger.error "Error updating employee activities: #{e.message}"
        Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
        render json: { success: false, message: "Error updating activities: #{e.message}" }, status: :unprocessable_entity
      end
    else
      render json: { success: false, message: 'No departments found for this employee' }
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

  def delete_employee_activities
    employee_id = params[:employee_id]
    
    Rails.logger.info "=== delete_employee_activities method called ==="
    Rails.logger.info "Deleting activities for employee: #{employee_id}"
    
    # Find all departments for this employee
    departments = Department.where(employee_reference: employee_id)
    Rails.logger.info "Found #{departments.count} departments for employee #{employee_id}"
    
    if departments.any?
      begin
        # Delete all activities and departments for this employee
        ActiveRecord::Base.transaction do
          departments.each do |dept|
            Rails.logger.info "Processing department #{dept.id} with #{dept.activities.count} activities"
            
                       # First, delete all records that reference these activities
           dept.activities.each do |activity|
             Rails.logger.info "Deleting references for activity #{activity.id}"
             
             # Delete user_details that reference this activity
             # This will automatically delete associated achievements and achievement_remarks due to dependent: :destroy
             user_details = UserDetail.where(activity_id: activity.id)
             user_details_count = user_details.count
             Rails.logger.info "Found #{user_details_count} user_details for activity #{activity.id}"
             
             # Delete the user_details (achievements and achievement_remarks will be deleted automatically)
             user_details.destroy_all
             Rails.logger.info "Deleted #{user_details_count} user_details for activity #{activity.id}"
           end
            
            # Now delete the activities
            activities_count = dept.activities.count
            dept.activities.destroy_all
            Rails.logger.info "Deleted #{activities_count} activities from department #{dept.id}"
            
            # Finally delete the department
            dept.destroy
            Rails.logger.info "Deleted department #{dept.id}"
          end
        end
        
        render json: { success: true, message: 'Employee activities deleted successfully!' }
      rescue => e
        Rails.logger.error "Error deleting employee activities: #{e.message}"
        Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
        render json: { success: false, message: "Error deleting activities: #{e.message}" }, status: :unprocessable_entity
      end
    else
      render json: { success: false, message: 'No activities found for this employee' }
    end
  end

  def test_route
    Rails.logger.info "=== test_route method called ==="
    render json: { success: true, message: 'Test route working!' }
  end

  def delete_activity
    activity_id = params[:activity_id]
    
    Rails.logger.info "=== delete_activity method called ==="
    Rails.logger.info "Deleting activity: #{activity_id}"
    
    begin
      activity = Activity.find(activity_id)
      
             ActiveRecord::Base.transaction do
         # First, delete all records that reference this activity
         user_details = UserDetail.where(activity_id: activity_id)
         user_details_count = user_details.count
         Rails.logger.info "Found #{user_details_count} user_details for activity #{activity_id}"
         
         # Delete the user_details (achievements and achievement_remarks will be deleted automatically due to dependent: :destroy)
         user_details.destroy_all
         Rails.logger.info "Deleted #{user_details_count} user_details for activity #{activity_id}"
         
         # Now delete the activity
         activity.destroy
         Rails.logger.info "Deleted activity #{activity_id}"
       end
      
      render json: { success: true, message: 'Activity deleted successfully!' }
    rescue ActiveRecord::RecordNotFound
      render json: { success: false, message: 'Activity not found' }, status: :not_found
    rescue => e
      Rails.logger.error "Error deleting activity: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
      render json: { success: false, message: "Error deleting activity: #{e.message}" }, status: :unprocessable_entity
    end
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

  # Get activities for a specific employee using UserDetail
  def get_employee_activities(employee)
    activities_hash = {}
    
    # Get all user_details for this employee
    user_details = UserDetail.includes(:activity, :department)
                            .where(employee_detail_id: employee.id)
                            .where.not(activity_id: nil)
    
    user_details.each do |user_detail|
      activity = user_detail.activity
      department = user_detail.department
      
      # Group by employee ONLY - no department grouping
      key = "#{employee.employee_id}"
      
      activities_hash[key] ||= {
        id: user_detail.id,
        employee_id: employee.employee_id,
        employee_name: employee.employee_name,
        employee_code: employee.employee_name,
        department: employee.department, # Employee's department
        department_type: department.department_type, # Activity's department
        total_activities: 0,
        activities: []
      }
      
      activities_hash[key][:activities] << {
        id: activity.id,
        theme_name: activity.theme_name,
        activity_name: activity.activity_name,
        unit: activity.unit,
        weight: activity.weight,
        department_type: department.department_type
      }
      activities_hash[key][:total_activities] += 1
    end
    
    activities_hash
  end

  # Get all employees with their activities grouped by employee
  def get_all_employee_activities
    activities_hash = {}
    
    # Get all employees who have user_details
    employees_with_activities = EmployeeDetail.joins(:user_details)
                                             .distinct
                                             .includes(:user_details)
    
    employees_with_activities.each do |employee|
      # Get activities for this employee
      user_details = UserDetail.includes(:activity, :department)
                              .where(employee_detail_id: employee.id)
                              .where.not(activity_id: nil)
      
      user_details.each do |user_detail|
        activity = user_detail.activity
        department = user_detail.department
        
        # Group by employee ONLY - no department grouping
        key = "#{employee.employee_id}"
        
        activities_hash[key] ||= {
          id: user_detail.id,
          employee_id: employee.employee_id,
          employee_name: employee.employee_name,
          employee_code: employee.employee_name,
          department: employee.department, # Employee's department
          department_type: department.department_type, # Activity's department
          total_activities: 0,
          activities: []
        }
        
        activities_hash[key][:activities] << {
          id: activity.id,
          theme_name: activity.theme_name,
          activity_name: activity.activity_name,
          unit: activity.unit,
          weight: activity.weight,
          department_type: department.department_type
        }
        activities_hash[key][:total_activities] += 1
      end
    end
    
    # Sort by employee name
    activities_hash.sort_by { |key, data| data[:employee_name] }.to_h
  end
end