require "roo"

class DepartmentsController < ApplicationController
  before_action :set_department, only: [ :show, :edit, :update, :destroy, :delete_user_activities, :delete_user_from_department ]

  def index
    if params[:employee_id].present?
      @selected_employee = EmployeeDetail.find_by(employee_code: params[:employee_id])
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

    # Debug logging - simplified to avoid database errors
    Rails.logger.info "Employee activities loaded successfully"

    @department = Department.new
    # Only build one activity by default to prevent duplicates
    @department.activities.build

    # Set variables needed for the form dropdowns
    @employee_departments =
      (Department.distinct.pluck(:department_type) + EmployeeDetail.distinct.pluck(:department))
        .compact
        .map { |d| d.to_s.strip }
        .reject(&:blank?)
        .uniq
        .sort

    # Get unique employees based on base employee code (remove department suffixes)
    all_employees = EmployeeDetail.where.not(employee_name: [ nil, "" ])
                                 .includes(:user_details)

    # Group by base employee code and get the first record for each
    unique_employees = {}
    all_employees.each do |emp|
      base_code = emp.employee_code.split("_").first
      unless unique_employees[base_code]
        unique_employees[base_code] = emp
      end
    end

    @employees = unique_employees.values.sort_by(&:employee_name)

    respond_to do |format|
      format.html
      format.json do
        render json: @employee_activities.values
      end
    end
  end

  def new
    @department = Department.new
    @employee_departments =
      (Department.distinct.pluck(:department_type) + EmployeeDetail.distinct.pluck(:department))
        .compact
        .map { |d| d.to_s.strip }
        .reject(&:blank?)
        .uniq
        .sort
    # Get all unique employees from both employee_details.department and user_details relationships
    # First get all unique employee codes
    employee_codes_from_department = EmployeeDetail.where.not(employee_name: [ nil, "" ])
                                                  .where.not(department: [ nil, "" ])
                                                  .distinct.pluck(:employee_code)

    employee_codes_from_user_details = EmployeeDetail.joins(user_details: :department)
                                                    .where.not(employee_name: [ nil, "" ])
                                                    .distinct.pluck(:employee_code)

    # Combine all unique employee codes
    all_employee_codes = (employee_codes_from_department + employee_codes_from_user_details).uniq

    # Get the first record for each unique employee code
    @employees = EmployeeDetail.where(employee_code: all_employee_codes)
                              .where(id: EmployeeDetail.select("MIN(id)").group(:employee_code))
                              .order(:employee_name)
    # Only build one activity by default to prevent duplicates
    @department.activities.build
  end

  def create
    # Find existing department with same type or create new one
    department_type = department_params[:department_type]
    employee_reference = department_params[:employee_reference]

    @department = Department.find_by(department_type: department_type)

    if @department
      # Department exists, add employee and activities
      Rails.logger.info "Found existing department #{department_type} (ID: #{@department.id})"

      activities_params = department_params[:activities_attributes]
      employee = EmployeeDetail.find_by(employee_code: employee_reference) if employee_reference.present?

      if activities_params.present? && employee
        activities_params.each do |index, activity_attrs|
          next if activity_attrs[:_destroy] == "true" || activity_attrs[:_destroy] == true
          next if activity_attrs[:theme_name].blank? || activity_attrs[:activity_name].blank?

          activity = @department.activities.find_or_create_by!(
            theme_name: activity_attrs[:theme_name],
            activity_name: activity_attrs[:activity_name]
          ) do |a|
            a.unit = activity_attrs[:unit]
            a.weight = activity_attrs[:weight]
          end

          UserDetail.find_or_create_by!(
            department_id: @department.id,
            activity_id: activity.id,
            employee_detail_id: employee.id
          )
        end
        success = true
        message = "Employee and activities successfully added to existing #{department_type} department!"
      else
        message = "No employee reference provided or no activities"
        success = false
      end
    else
      # Create new department
      Rails.logger.info "Creating new department for #{department_type}"
      @department = Department.new(department_params)
      success = @department.save

      if success && employee_reference.present?
        employee = EmployeeDetail.find_by(employee_code: employee_reference)
        if employee
          @department.activities.each do |act|
            UserDetail.find_or_create_by!(
              department_id: @department.id,
              activity_id: act.id,
              employee_detail_id: employee.id
            )
          end
        end
      end

      message = success ? "Department was successfully created." : "Failed to create department: #{@department.errors.full_messages.join(', ')}"
    end

    if success
      respond_to do |format|
        format.html { redirect_to departments_path, notice: message }
        format.json { render json: { success: true, message: message } }
      end
    else
      respond_to do |format|
        format.html {
          @department = Department.new
          @department.activities.build
          @departments = Department.includes(:activities).all
          @employee_departments =
            (Department.distinct.pluck(:department_type) + EmployeeDetail.distinct.pluck(:department))
              .compact
              .map { |d| d.to_s.strip }
              .reject(&:blank?)
              .uniq
              .sort
          @employees = EmployeeDetail.where("employee_name IS NOT NULL AND employee_name != ''")
                                   .distinct
                                   .order(:employee_name)
          # Set employee_activities to avoid nil error in view
          @employee_activities = get_all_employee_activities
          flash.now[:alert] = "Failed to create department: #{@department.errors.full_messages.join(', ')}"
          render :index, status: :unprocessable_entity
        }
        format.json { render json: { success: false, errors: @department.errors.full_messages } }
      end
    end
  end

  def edit
    @department = Department.find(params[:id])
    @employee_departments =
      (Department.distinct.pluck(:department_type) + EmployeeDetail.distinct.pluck(:department))
        .compact
        .map { |d| d.to_s.strip }
        .reject(&:blank?)
        .uniq
        .sort
    # Get all unique employees from both employee_details.department and user_details relationships
    # First get all unique employee codes
    employee_codes_from_department = EmployeeDetail.where.not(employee_name: [ nil, "" ])
                                                  .where.not(department: [ nil, "" ])
                                                  .distinct.pluck(:employee_code)

    employee_codes_from_user_details = EmployeeDetail.joins(user_details: :department)
                                                    .where.not(employee_name: [ nil, "" ])
                                                    .distinct.pluck(:employee_code)

    # Combine all unique employee codes
    all_employee_codes = (employee_codes_from_department + employee_codes_from_user_details).uniq

    # Get the first record for each unique employee code
    @employees = EmployeeDetail.where(employee_code: all_employee_codes)
                              .where(id: EmployeeDetail.select("MIN(id)").group(:employee_code))
                              .select(:employee_name, :employee_code, :department)
                              .order(:employee_name)
  end

  def edit_data
    # The frontend is actually trying to edit employee activities, not departments
    # We need to find the employee and their activities based on the department ID

    # First try to find the department
    department = Department.find_by(id: params[:id])

    if department
      # Find the specific employee from the employee_id parameter
      employee_id = params[:employee_id]
      employee = EmployeeDetail.find_by(employee_code: employee_id) if employee_id.present?

      if employee
        Rails.logger.info "Getting employee-specific activities for employee #{employee.employee_code} in department #{department.id}"

        # Get all employee records with the same base employee code (handles department suffixes)
        base_employee_code = employee.employee_code.split("_").first
        all_employee_records = EmployeeDetail.where("employee_code LIKE ? OR employee_code = ?", "#{base_employee_code}_%", base_employee_code)

        Rails.logger.info "Found #{all_employee_records.count} employee records for base code #{base_employee_code}"

        # Get activities from UserDetail records for ALL related employee records in this department
        user_details = UserDetail.includes(:activity, :department)
                                .where(employee_detail_id: all_employee_records.pluck(:id))
                                .where(department_id: department.id)
                                .where("activity_id IS NOT NULL")

        Rails.logger.info "Found #{user_details.count} user_details for employee #{employee.employee_code} in department #{department.id}"

        # Map activities from user_details (employee-specific activities)
        activities = user_details.map do |user_detail|
          activity = user_detail.activity
          Rails.logger.info "Processing employee-specific activity #{activity.id}: #{activity.activity_name}"
          {
            id: activity.id,
            theme_name: activity.theme_name,
            activity_name: activity.activity_name,
            unit: activity.unit,
            weight: activity.weight
          }
        end.uniq { |activity| activity[:id] } # Remove duplicates

        Rails.logger.info "Found #{activities.length} employee-specific activities for edit"

        employee_name = employee.employee_name
        employee_code = employee.employee_code

        render json: {
          id: department.id,
          department_type: department.department_type,
          theme_name: department.theme_name,
          employee_reference: employee.employee_code,
          employee_name: employee_name,
          employee_code: employee_code,
          employee_display_name: employee ? "#{employee_name} (#{employee_code})" : "N/A",
          activities: activities
        }
      else
        # No employee found for this department
        render json: { error: "No employee found for this department" }, status: :not_found
      end
    else
      # If department doesn't exist, try to find employee activities by employee ID
      # This handles the case where the ID might actually be an employee ID
      employee = EmployeeDetail.find_by(employee_code: params[:id])

      if employee
        # Get all employee records with the same base employee code
        base_employee_code = employee.employee_code.split("_").first
        all_employee_records = EmployeeDetail.where("employee_code LIKE ? OR employee_code = ?", "#{base_employee_code}_%", base_employee_code)

        # Get activities for this employee using UserDetail
        user_details = UserDetail.includes(:activity, :department)
                                .where(employee_detail_id: all_employee_records.pluck(:id))
                                .where("activity_id IS NOT NULL")

        activities = user_details.map do |user_detail|
          activity = user_detail.activity
          {
            id: activity.id,
            theme_name: activity.theme_name,
            activity_name: activity.activity_name,
            unit: activity.unit,
            weight: activity.weight
          }
        end

        # Find the department type from the first activity
        department_type = user_details.first&.department&.department_type || employee.department

        render json: {
          id: employee.employee_code, # Use employee code as the identifier
          department_type: department_type,
          theme_name: "", # No theme name for employee activities
          employee_reference: employee.employee_code,
          employee_name: employee.employee_name,
          employee_code: employee.employee_code,
          employee_display_name: "#{employee.employee_name} (#{employee.employee_code})",
          activities: activities
        }
      else
        # Neither department nor employee found
        render json: { error: "Department or employee not found" }, status: :not_found
      end
    end
  end

  # Handle employee-specific activity updates
  def handle_employee_activity_update(employee)
    Rails.logger.info "=== handle_employee_activity_update called for employee #{employee.employee_code} ==="

    if params[:department] && params[:department][:activities_attributes].present?
      Rails.logger.info "Processing employee activity updates for #{employee.employee_name}"

      begin
        ActiveRecord::Base.transaction do
          # Get existing UserDetail records for this employee
          existing_user_details = UserDetail.where(employee_detail_id: employee.id)
          Rails.logger.info "Found #{existing_user_details.count} existing user_details for employee"

          # Process activities marked for destruction (remove from employee)
          activities_to_remove_from_employee = []
          params[:department][:activities_attributes].each do |index, activity_attrs|
            if (activity_attrs[:_destroy] == "true" || activity_attrs[:_destroy] == true) && activity_attrs[:id].present? && activity_attrs[:id] != ""
              Rails.logger.info "Activity #{activity_attrs[:id]} marked for removal from employee #{employee.employee_code}"
              activities_to_remove_from_employee << activity_attrs[:id]
            end
          end

          # Remove UserDetail records for activities marked for destruction
          activities_to_remove_from_employee.each do |activity_id|
            user_details_to_remove = existing_user_details.where(activity_id: activity_id)
            if user_details_to_remove.any?
              Rails.logger.info "Removing #{user_details_to_remove.count} user_details for activity #{activity_id} from employee #{employee.employee_code}"
              user_details_to_remove.destroy_all
            end
          end

          # Process remaining activities (update existing or create new UserDetail records)
          Rails.logger.info "Processing #{params[:department][:activities_attributes].count} activities for update"
          params[:department][:activities_attributes].each do |index, activity_attrs|
            # Skip if marked for destruction
            next if activity_attrs[:_destroy] == "true" || activity_attrs[:_destroy] == true

            # Skip if incomplete
            next if activity_attrs[:theme_name].blank? || activity_attrs[:activity_name].blank? || activity_attrs[:weight].blank?

            activity_id = activity_attrs[:id]
            if activity_id.present?
              # Update existing Activity record
              activity = Activity.find_by(id: activity_id)
              if activity
                Rails.logger.info "Updating existing activity #{activity_id}"
                activity.update!(
                  theme_name: activity_attrs[:theme_name],
                  activity_name: activity_attrs[:activity_name],
                  unit: activity_attrs[:unit],
                  weight: activity_attrs[:weight]
                )

                # Ensure UserDetail record exists for this activity
                user_detail = existing_user_details.find_by(activity_id: activity_id)
                unless user_detail
                  Rails.logger.info "Creating missing user_detail for activity #{activity_id}"
                  UserDetail.create!(
                    employee_detail_id: employee.id,
                    activity_id: activity_id,
                    department_id: activity.department_id
                  )
                end
              else
                Rails.logger.warn "Activity with ID #{activity_id} not found"
              end
            else
              # Create new activity (this case might not be needed for employee editing)
              Rails.logger.info "Creating new activity for employee #{employee.employee_code}"
              # For new activities, we need to find an appropriate department
              # Use the first existing department for this employee, or create one
              existing_dept = existing_user_details.first&.department
              if existing_dept
                new_activity = existing_dept.activities.create!(
                  theme_name: activity_attrs[:theme_name],
                  activity_name: activity_attrs[:activity_name],
                  unit: activity_attrs[:unit],
                  weight: activity_attrs[:weight]
                )

                UserDetail.create!(
                  employee_detail_id: employee.id,
                  activity_id: new_activity.id,
                  department_id: existing_dept.id
                )
                Rails.logger.info "Created new activity #{new_activity.id} and user_detail"
              else
                Rails.logger.error "No existing department found for employee to create new activity"
              end
            end
          end

          Rails.logger.info "Successfully updated employee activities for #{employee.employee_name}"
          render json: { success: true, message: "Employee activities updated successfully!" }
        end
      rescue => e
        Rails.logger.error "Error updating employee activities: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        render json: { success: false, message: "Error updating employee activities: #{e.message}" }, status: :unprocessable_entity
      end
    else
      Rails.logger.warn "No activities attributes found in params"
      render json: { success: false, message: "No activities data provided" }, status: :unprocessable_entity
    end
  end

  def update
    # Handle nested attributes with proper foreign key constraint handling
    begin
      ActiveRecord::Base.transaction do
        # First, handle activities marked for destruction
        if department_params[:activities_attributes].present?
          department_params[:activities_attributes].each do |index, activity_attrs|
            if activity_attrs[:_destroy] == "true" && activity_attrs[:id].present?
              activity = Activity.find(activity_attrs[:id])

              # First delete dependent user_details records to avoid foreign key constraint violation
              user_details = UserDetail.where(activity_id: activity.id)
              if user_details.any?
                Rails.logger.info "Found #{user_details.count} user_details for activity #{activity.id}, deleting them first"
                user_details.destroy_all
              end

              # Now delete the activity
              activity.destroy
              Rails.logger.info "Successfully deleted activity #{activity.id}"
            end
          end
        end

    # Now update the department with the remaining activities
    if @department.update(department_params)
      respond_to do |format|
        format.html { redirect_to departments_path, notice: "Department was successfully updated." }
        format.json { render json: { success: true, message: "Department updated successfully!" } }
      end
    else
      respond_to do |format|
        format.html {
          @employee_departments =
            (Department.distinct.pluck(:department_type) + EmployeeDetail.distinct.pluck(:department))
              .compact
              .map { |d| d.to_s.strip }
              .reject(&:blank?)
              .uniq
              .sort
          @employees = EmployeeDetail.where("employee_name IS NOT NULL AND employee_name != ''")
                                   .select(:employee_name, :employee_code, :department)
                                   .distinct
                                   .order(:employee_name)
          render :edit, status: :unprocessable_entity
        }
        format.json { render json: { success: false, errors: @department.errors.full_messages } }
          end
    end
      end
    rescue => e
      Rails.logger.error "Error updating department: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      respond_to do |format|
        format.html {
          @employee_departments =
            (Department.distinct.pluck(:department_type) + EmployeeDetail.distinct.pluck(:department))
              .compact
              .map { |d| d.to_s.strip }
              .reject(&:blank?)
              .uniq
              .sort
          @employees = EmployeeDetail.where("employee_name IS NOT NULL AND employee_name != ''")
                                   .select(:employee_name, :employee_code, :department)
                                   .distinct
                                   .order(:employee_name)
          flash.now[:alert] = "Failed to update department: #{e.message}"
          render :edit, status: :unprocessable_entity
        }
        format.json { render json: { success: false, errors: [ e.message ] } }
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

               # Delete activities that are no longer in the form
               activities_to_delete.each do |activity|
                 Rails.logger.info "Deleting activity #{activity.id} (#{activity.activity_name})"

                 # First delete dependent user_details records to avoid foreign key constraint violation
                 user_details = UserDetail.where(activity_id: activity.id)
                 if user_details.any?
                   Rails.logger.info "Found #{user_details.count} user_details for activity #{activity.id}, deleting them first"
                 user_details.destroy_all
                 end

                 # Now delete the activity
                 activity.destroy
                 Rails.logger.info "Successfully deleted activity #{activity.id}"
               end

               # Update or create activities
               params[:activities].each do |activity_params|
                 # Try to find existing activity by content
                 existing_activity = dept.activities.find_by(
                   theme_name: activity_params[:theme_name],
                   activity_name: activity_params[:activity_name],
                   unit: activity_params[:unit],
                   weight: activity_params[:weight]
                 )

                 if existing_activity
                   # Update existing activity
                   Rails.logger.info "Updating existing activity #{existing_activity.id}"
                   existing_activity.update!(
                     theme_name: activity_params[:theme_name],
                     activity_name: activity_params[:activity_name],
                     unit: activity_params[:unit],
                     weight: activity_params[:weight]
                   )
                 else
                   # Create new activity
                   Rails.logger.info "Creating new activity for department #{dept.id}"
                   new_activity = dept.activities.create!(
                     theme_name: activity_params[:theme_name],
                     activity_name: activity_params[:activity_name],
                     unit: activity_params[:unit],
                     weight: activity_params[:weight]
                   )
                   Rails.logger.info "Created new activity #{new_activity.id}"
                 end
               end
                                      end
          end

          Rails.logger.info "Successfully updated activities for employee #{employee_id}"
          render json: { success: true, message: "Employee activities updated successfully!" }
        end
      rescue => e
        Rails.logger.error "Error updating employee activities: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        render json: { success: false, message: "Error updating activities: #{e.message}" }, status: :unprocessable_entity
      end
    else
      Rails.logger.warn "No departments found for employee #{employee_id}"
      render json: { success: false, message: "No departments found for this employee" }, status: :not_found
    end
  end

  # New action to handle updating employee activity data from the edit form
  def update_employee_activity_data
    Rails.logger.info "=== update_employee_activity_data method called ==="

    department = Department.find_by(id: params[:id])
    employee_code = params.dig(:department, :employee_reference)
    employee = EmployeeDetail.find_by(employee_code: employee_code) if employee_code.present?

    if !department || !employee
      return render json: { success: false, message: "Department or Employee not found" }, status: :not_found
    end

    Rails.logger.info "Editing activities for Employee: #{employee.employee_code} in Department: #{department.id}"

    if params[:department] && params[:department][:activities_attributes].present?
      begin
        ActiveRecord::Base.transaction do
          form_activity_ids = []

          params[:department][:activities_attributes].each do |index, activity_attrs|
            # Skip incomplete new activities
            if activity_attrs[:id].blank? && (activity_attrs[:theme_name].blank? || activity_attrs[:activity_name].blank? || activity_attrs[:weight].blank?)
              next
            end

            # If marked for destruction
            if activity_attrs[:_destroy] == "true" || activity_attrs[:_destroy] == true
              if activity_attrs[:id].present?
                # Destroy UserDetail for this employee
                UserDetail.where(department_id: department.id, activity_id: activity_attrs[:id], employee_detail_id: employee.id).destroy_all

                # If no one else uses this activity, delete the activity itself
                unless UserDetail.exists?(activity_id: activity_attrs[:id])
                  Activity.find_by(id: activity_attrs[:id])&.destroy
                end
              end
              next
            end

            # It's a valid activity to keep/update/create
            if activity_attrs[:id].present?
              activity = Activity.find_by(id: activity_attrs[:id])
              if activity
                activity.update!(
                  theme_name: activity_attrs[:theme_name],
                  activity_name: activity_attrs[:activity_name],
                  unit: activity_attrs[:unit],
                  weight: activity_attrs[:weight]
                )
                form_activity_ids << activity.id

                # Ensure UserDetail exists
                UserDetail.find_or_create_by!(
                  department_id: department.id,
                  activity_id: activity.id,
                  employee_detail_id: employee.id
                )
              end
            else
              # Create new activity and UserDetail
              new_activity = department.activities.create!(
                theme_name: activity_attrs[:theme_name],
                activity_name: activity_attrs[:activity_name],
                unit: activity_attrs[:unit],
                weight: activity_attrs[:weight]
              )
              form_activity_ids << new_activity.id

              UserDetail.create!(
                department_id: department.id,
                activity_id: new_activity.id,
                employee_detail_id: employee.id
              )
            end
          end

          # Any existing UserDetail for this employee & dept not in the form should be removed
          user_details_to_remove = UserDetail.where(department_id: department.id, employee_detail_id: employee.id)
          user_details_to_remove = user_details_to_remove.where.not(activity_id: form_activity_ids) if form_activity_ids.any?

          activity_ids_to_check = user_details_to_remove.pluck(:activity_id)
          user_details_to_remove.destroy_all

          # Clean up any orphaned activities
          activity_ids_to_check.each do |act_id|
            unless UserDetail.exists?(activity_id: act_id)
              Activity.find_by(id: act_id)&.destroy
            end
          end

          render json: { success: true, message: "Employee activities updated successfully!" }
        end
      rescue => e
        Rails.logger.error "Error updating employee activities: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        render json: { success: false, message: "Error updating activities: #{e.message}" }, status: :unprocessable_entity
      end
    else
      render json: { success: false, message: "No activities provided" }, status: :unprocessable_entity
    end
  end

  def import
    file = params[:file]

    if file.nil?
      redirect_to departments_path, alert: "Please upload a file."
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
      "Weightage" => "weight",
      "Weight" => "weight"
    }

    departments_hash = {}
    import_errors = []
    success_count = 0

    (2..spreadsheet.last_row).each do |i|
      row_data = spreadsheet.row(i)
      row = Hash[[ header, row_data ].transpose]
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

      # Create unique key for each department-employee combination (not by theme)
      # This ensures same employee in same department gets only one entry
      key = "#{mapped["department_type"]}-#{employee.employee_code}"
      departments_hash[key] ||= {
        department_type: mapped["department_type"],
        employee_reference: employee.employee_code,
        theme_name: mapped["theme_name"], # Keep first theme name as default
        activities: []
      }

      # Only add activity if activity data is present
      if mapped["activity_name"].present?
        # Process weight value similar to user_details import
        processed_weight = if mapped["weight"].present?
          weight_str = mapped["weight"].to_s.strip
          Rails.logger.info "Processing weight for row #{i}: original_weight=#{mapped['weight']}, weight_str=#{weight_str}"

          if weight_str.include?("%")
            # If it contains %, remove the % and use the number as-is
            result = weight_str.gsub("%", "").to_f
            Rails.logger.info "Weight processing: percentage format, result=#{result}"
            result
          elsif weight_str.to_f < 1 && weight_str.to_f > 0
            # If it's a decimal like 0.1, convert to percentage (0.1 -> 10)
            result = weight_str.to_f * 100
            Rails.logger.info "Weight processing: decimal format, result=#{result}"
            result
          else
            # If it's already a whole number like 10, use as-is
            result = weight_str.to_f
            Rails.logger.info "Weight processing: whole number format, result=#{result}"
            result
          end
        else
          Rails.logger.info "Processing weight for row #{i}: no weight value present"
          nil
        end

        departments_hash[key][:activities] << {
          theme_name: mapped["theme_name"],
          activity_name: mapped["activity_name"],
          unit: mapped["unit"],
          weight: processed_weight
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
        # Check if department already exists (by department_type only, not employee)
        existing_department = Department.find_by(
          department_type: dept_data[:department_type]
        )

        if existing_department
          employee = EmployeeDetail.find_by(employee_code: dept_data[:employee_reference]) if dept_data[:employee_reference].present?

          # Department exists, add activities and employee to it
          dept_data[:activities].each do |act|
            # Check if activity already exists to avoid duplicates
            activity = existing_department.activities.find_or_create_by!(
              activity_name: act[:activity_name],
              theme_name: act[:theme_name]
            ) do |a|
              a.unit = act[:unit]
              a.weight = act[:weight]
            end

            if employee
              UserDetail.find_or_create_by!(
                department_id: existing_department.id,
                activity_id: activity.id,
                employee_detail_id: employee.id
              )
            end
          end
        else
          # Create new department
          department = Department.create!(
            department_type: dept_data[:department_type],
            employee_reference: dept_data[:employee_reference],
            theme_name: dept_data[:theme_name]
          )

          employee = EmployeeDetail.find_by(employee_code: dept_data[:employee_reference]) if dept_data[:employee_reference].present?

          dept_data[:activities].each do |act|
            activity = department.activities.create!(act)
            if employee
              UserDetail.find_or_create_by!(
                department_id: department.id,
                activity_id: activity.id,
                employee_detail_id: employee.id
              )
            end
          end
        end

        success_count += 1
      end
    end

    redirect_to departments_path, notice: "✅ Successfully imported #{success_count} department(s) with activities!"
  rescue => e
    redirect_to departments_path, alert: "❌ Import failed: #{e.message}"
  end

  def export
    # Get all user_details with their associations to ensure we have complete data
    @user_details = UserDetail.includes(:employee_detail, :department, :activity)
                              .where("user_details.activity_id IS NOT NULL")
                              .order("employee_details.employee_name, departments.department_type, activities.theme_name, activities.activity_name")

    respond_to do |format|
      format.xlsx {
        response.headers["Content-Disposition"] = 'attachment; filename="departments_export.xlsx"'
        render xlsx: "export", template: "departments/export"
      }
    end
  end

  def activity_list
    @employee_code = params[:employee_code]
    @department_id = params[:department_id]

    if @employee_code.present? && @department_id.present?
      @employee = EmployeeDetail.find_by(employee_code: @employee_code)
      @department = Department.find_by(id: @department_id)

      if @employee && @department
        # Get all employee records with the same base employee code
        base_employee_code = @employee.employee_code.split("_").first
        all_employee_records = EmployeeDetail.where("employee_code LIKE ? OR employee_code = ?", "#{base_employee_code}_%", base_employee_code)

        # Get activities for all related employee records in this department
        @user_details = UserDetail.includes(:activity)
                                 .where(employee_detail_id: all_employee_records.pluck(:id))
                                 .where(department_id: @department.id)
                                 .where("activity_id IS NOT NULL")

        @activities = @user_details.map(&:activity).compact.uniq

        # Get L1, L2, L3 info
        @l1_info = @employee.l1_for_department(@department.id)
        @l2_info = @employee.l2_for_department(@department.id)
        @l3_info = @employee.l3_for_department(@department.id)
      else
        redirect_to departments_path, alert: "Employee or Department not found"
        nil
      end
    else
      redirect_to departments_path, alert: "Missing employee or department information"
      nil
    end
  end

  def destroy
    begin
      # Check if this is a request to delete a specific user's activities
      if params[:user_id].present?
        # Delete only specific user's activities from this department
        delete_user_activities_from_department(params[:user_id])
        message = "User activities deleted successfully from this department."
      else
        # Delete the entire department (existing behavior)
        ActiveRecord::Base.transaction do
          # First, delete all records that reference activities in this department
          @department.activities.each do |activity|
            # Delete user_details that reference this activity
            user_details = UserDetail.where(activity_id: activity.id)
            user_details.destroy_all
          end

          # Now delete the activities
          @department.activities.destroy_all

          # Finally delete the department
          @department.destroy
        end
        message = "Department was successfully deleted."
      end

      respond_to do |format|
        format.html { redirect_to departments_path, notice: message }
        format.json { render json: { success: true, message: message } }
      end
    rescue => e
      Rails.logger.error "Error deleting department: #{e.message}"
      respond_to do |format|
        format.html { redirect_to departments_path, alert: "Error deleting department: #{e.message}" }
        format.json { render json: { success: false, message: "Error deleting department: #{e.message}" }, status: :unprocessable_entity }
      end
    end
  end

  # New method to delete specific user's activities from a department
  def delete_user_activities_from_department(user_id)
    Rails.logger.info "=== delete_user_activities_from_department method called ==="
    Rails.logger.info "Deleting activities for user: #{user_id} from department: #{@department.id}"

    begin
      ActiveRecord::Base.transaction do
        # Find the employee detail for this user
        employee_detail = EmployeeDetail.find_by(employee_code: user_id)

        if employee_detail
          Rails.logger.info "Found employee: #{employee_detail.employee_name}"

          # Find all user_details for this specific employee in this department
          user_details = UserDetail.where(
            department_id: @department.id,
            employee_detail_id: employee_detail.id
          )

          user_details_count = user_details.count
          Rails.logger.info "Found #{user_details_count} user_details for employee #{employee_detail.employee_name} in department #{@department.id}"

          if user_details_count > 0
            # Delete the user_details (achievements and achievement_remarks will be deleted automatically due to dependent: :destroy)
            user_details.destroy_all
            Rails.logger.info "Deleted #{user_details_count} user_details for employee #{employee_detail.employee_name}"

            # Check if this was the only employee in this department
            remaining_user_details = UserDetail.where(department_id: @department.id)

            if remaining_user_details.count == 0
              Rails.logger.info "No more user_details in department #{@department.id}, deleting department and activities"
              # If no more user_details, delete the department and activities
              @department.activities.destroy_all
              @department.destroy
            else
              Rails.logger.info "Department #{@department.id} still has #{remaining_user_details.count} other user_details, keeping department"
            end
          else
            Rails.logger.info "No user_details found for employee #{employee_detail.employee_name} in department #{@department.id}"
          end
        else
          Rails.logger.error "Employee detail not found for user_id: #{user_id}"
          raise "Employee not found"
        end
      end
    rescue => e
      Rails.logger.error "Error deleting user activities: #{e.message}"
      raise e
    end
  end

  # New method to handle the delete_user_activities route
  def delete_user_activities
    # Handle both form data and JSON parameters
    user_id = params[:employee_id] || params[:user_id]

    if user_id.blank?
      respond_to do |format|
        format.html { redirect_to departments_path, alert: "Employee ID is required" }
        format.json { render json: { success: false, message: "Employee ID is required" }, status: :bad_request }
      end
      return
    end

    Rails.logger.info "delete_user_activities called with user_id: #{user_id}"

    begin
      delete_user_activities_from_department(user_id)

      respond_to do |format|
        format.html { redirect_to departments_path, notice: "User activities deleted successfully from this department!" }
        format.json { render json: { success: true, message: "User activities deleted successfully from this department!" } }
      end
    rescue => e
      Rails.logger.error "Error in delete_user_activities: #{e.message}"

      respond_to do |format|
        format.html { redirect_to departments_path, alert: "Error deleting user activities: #{e.message}" }
        format.json { render json: { success: false, message: "Error deleting user activities: #{e.message}" }, status: :unprocessable_entity }
      end
    end
  end

  # New method to handle the delete_user_from_department route
  def delete_user_from_department
    user_id = params[:user_id] || params[:employee_id]

    if user_id.blank?
      render json: { success: false, message: "User ID is required" }, status: :bad_request
      return
    end

    begin
      delete_user_activities_from_department(user_id)
      render json: { success: true, message: "User deleted successfully from this department!" }
    rescue => e
      Rails.logger.error "Error in delete_user_from_department: #{e.message}"
      render json: { success: false, message: "Error deleting user from department: #{e.message}" }, status: :unprocessable_entity
    end
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

        render json: { success: true, message: "Employee activities deleted successfully!" }
      rescue => e
        Rails.logger.error "Error deleting employee activities: #{e.message}"
        Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
        render json: { success: false, message: "Error deleting activities: #{e.message}" }, status: :unprocessable_entity
      end
    else
      render json: { success: false, message: "No activities found for this employee" }
    end
  end

  def test_route
    Rails.logger.info "=== test_route method called ==="
    render json: { success: true, message: "Test route working!" }
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

      render json: { success: true, message: "Activity deleted successfully!" }
    rescue ActiveRecord::RecordNotFound
      render json: { success: false, message: "Activity not found" }, status: :not_found
    rescue => e
      Rails.logger.error "Error deleting activity: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
      render json: { success: false, message: "Error deleting activity: #{e.message}" }, status: :unprocessable_entity
    end
  end


  private

  def set_department
    @department = Department.find(params[:id])
  end

  def department_params
    params.require(:department).permit(:department_type, :employee_reference, :theme_name,
    activities_attributes: [ :id, :theme_name, :activity_name, :unit, :weight, :_destroy ])
  end

  # Get activities for a specific employee using UserDetail - supporting multiple departments
  def get_employee_activities(employee)
    activities_hash = {}

    # Get all user_details for this employee grouped by department
    user_details = UserDetail.includes(:activity, :department)
                            .where(employee_detail_id: employee.id)
                            .where("activity_id IS NOT NULL")

    # Group by department to show one entry per employee+department combination
    user_details.group_by(&:department).each do |department, dept_user_details|
      # Skip if department is nil
      next unless department

      # Create unique key for employee + department combination
      key = "#{employee.employee_code}_#{department.id}"

      # Get L1/L2/L3 info for this department
      l1_info = employee.l1_for_department(department.id)
      l2_info = employee.l2_for_department(department.id)
      l3_info = employee.l3_for_department(department.id)

      # Count unique activities for this employee in this department
      unique_activities = dept_user_details.map(&:activity).compact.uniq

      activities_hash[key] = {
        id: department.id, # Use department.id for Edit functionality
        employee_id: employee.employee_code,
        employee_name: employee.employee_name,
        employee_code: employee.employee_code,
        department: employee.department, # Employee's primary department
        department_type: department.department_type, # Activity's department
        department_id: department.id,
        l1_code: l1_info[:code],
        l1_name: l1_info[:name],
        l2_code: l2_info[:code],
        l2_name: l2_info[:name],
        l3_code: l3_info[:code],
        l3_name: l3_info[:name],
        total_activities: unique_activities.count,
        activities: unique_activities.map do |activity|
          {
            id: activity.id,
            theme_name: activity.theme_name,
            activity_name: activity.activity_name,
            unit: activity.unit,
            weight: activity.weight,
            department_type: department.department_type
          }
        end
      }
    end

    activities_hash
  end

  # Get all employees with their activities grouped by employee and department
  def get_all_employee_activities
    activities_hash = {}
    seen_combinations = Set.new

    # Get all employees who have user_details with all associations in one query
    employees_with_activities = EmployeeDetail.joins(:user_details)
                                             .distinct
                                             .includes(user_details: [ :activity, :department ])

    # Group employees by base employee code to avoid processing multiple records for same person
    employees_by_base_code = {}
    employees_with_activities.each do |employee|
      base_employee_code = employee.employee_code.split("_").first
      employees_by_base_code[base_employee_code] ||= []
      employees_by_base_code[base_employee_code] << employee
    end

    # Process each unique base employee code only once
    employees_by_base_code.each do |base_employee_code, employee_records|
      # Use the first employee record as the representative (they should all have same name)
      representative_employee = employee_records.first

      # Get all user_details for all employee records with this base code
      all_employee_ids = employee_records.map(&:id)
      all_user_details = UserDetail.includes(:activity, :department)
                                  .where(employee_detail_id: all_employee_ids)
                                  .where("activity_id IS NOT NULL")

      # Group by department to show one entry per employee+department combination
      all_user_details.group_by(&:department).each do |department, dept_user_details|
        # Skip if department is nil
        next unless department

        # Create unique key for employee + department combination using base employee code
        key = "#{base_employee_code}_#{department.id}"

        # Skip if this combination already exists (avoid duplicates)
        next if seen_combinations.include?(key)
        seen_combinations.add(key)

        # Get L1/L2/L3 info for this department using the representative employee
        l1_info = representative_employee.l1_for_department(department.id)
        l2_info = representative_employee.l2_for_department(department.id)
        l3_info = representative_employee.l3_for_department(department.id)

        # Count unique activities for this employee in this department
        unique_activity_ids = dept_user_details.map(&:activity_id).compact.uniq
        unique_activities = Activity.where(id: unique_activity_ids)

        activities_hash[key] = {
          id: department.id, # Use department.id for Edit functionality
          employee_id: representative_employee.employee_code,
          display_employee_code: base_employee_code, # Clean employee code for display
          employee_name: representative_employee.employee_name,
          employee_code: representative_employee.employee_code,
          department: representative_employee.department, # Employee's primary department
          department_type: department.department_type, # Activity's department
          department_id: department.id,
          l1_code: l1_info[:code],
          l1_name: l1_info[:name],
          l2_code: l2_info[:code],
          l2_name: l2_info[:name],
          l3_code: l3_info[:code],
          l3_name: l3_info[:name],
          total_activities: unique_activities.count,
          activities: unique_activities.map do |activity|
            {
              id: activity.id,
              theme_name: activity.theme_name,
              activity_name: activity.activity_name,
              unit: activity.unit,
              weight: activity.weight,
              department_type: department.department_type
            }
          end
        }
      end
    end

    # Sort by employee name then department
    activities_hash.sort_by { |key, data| [ data[:employee_name], data[:department_type] ] }.to_h
  end
end
