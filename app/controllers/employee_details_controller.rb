require "roo"
require "axlsx"

class EmployeeDetailsController < ApplicationController
  before_action :set_employee_detail, only: [ :edit, :update, :destroy ]
  before_action :set_financial_year_context, only: [ :l1, :l2, :l3, :show, :show_l2, :show_l3, :get_status ]
  load_and_authorize_resource except: [ :approve, :return, :l2_approve, :l2_return, :l3_approve, :l3_return ]

  def index
    @employee_detail = EmployeeDetail.new
    @q = EmployeeDetail.ransack(params[:q])

    # Get all employee details with their user_details
    employee_details = @q.result
                         .includes(:user, user_details: [ :department, :activity, achievements: :achievement_remark ])
                         .order(created_at: :desc)

    # Create a list of unique employee-department combinations
    @employee_department_entries = []
    seen_combinations = Set.new

    # Get all employee records (both original and department-specific)
    all_employees = EmployeeDetail.includes(:user, user_details: [ :department, :activity, achievements: :achievement_remark ])
                                 .order(created_at: :desc)

    all_employees.each do |emp|
      if emp.user_details.any?
        # Group user_details by department to ensure we only get one entry per department
        emp.user_details.includes(:department).group_by(&:department).each do |department, user_details_for_dept|
          # Create a unique key for employee-department combination
          # Use base employee code (remove department suffix if exists)
          base_employee_code = emp.employee_code.split("_").first
          combination_key = "#{base_employee_code}_#{department.id}"

          # Only add if we haven't seen this combination before
          unless seen_combinations.include?(combination_key)
            seen_combinations.add(combination_key)
            # Use the first user_detail for this department (they should all be the same department)
            user_detail = user_details_for_dept.first

            @employee_department_entries << {
              employee: emp,
              department: department,
              user_detail: user_detail,
              l1_code: emp.l1_code,
              l1_name: emp.l1_employer_name,
              l2_code: emp.l2_code,
              l2_name: emp.l2_employer_name,
              l3_code: emp.l3_code,
              l3_name: emp.l3_employer_name
            }
          end
        end
      else
        # If employee has no user_details, show with default department
        combination_key = "#{emp.employee_code}_default"

        unless seen_combinations.include?(combination_key)
          seen_combinations.add(combination_key)
          @employee_department_entries << {
            employee: emp,
            department: nil,
            user_detail: nil,
            l1_code: emp.l1_code,
            l1_name: emp.l1_employer_name,
            l2_code: emp.l2_code,
            l2_name: emp.l2_employer_name,
            l3_code: emp.l3_code,
            l3_name: emp.l3_employer_name
          }
        end
      end
    end

    # Paginate the entries
    @employee_department_entries = Kaminari.paginate_array(@employee_department_entries)
                                          .page(params[:page])
                                          .per(10)
  end

  def create
    @employee_detail = EmployeeDetail.new(employee_detail_params)
    @employee_detail.user = current_user

    @q = EmployeeDetail.ransack(params[:q])
    if @employee_detail.save
      # Send SMS notification to L1 manager about new employee creation
      send_employee_creation_sms(@employee_detail)
      redirect_to employee_details_path, notice: "Employee created successfully."
    else
      # Rebuild the employee_department_entries for the form
      employee_details = @q.result
                           .includes(:user, user_details: [ :department, :activity, achievements: :achievement_remark ])
                           .order(created_at: :desc)

      @employee_department_entries = []
      seen_combinations = Set.new

      employee_details.each do |emp|
        if emp.user_details.any?
          # Group user_details by department to ensure we only get one entry per department
          emp.user_details.includes(:department).group_by(&:department).each do |department, user_details_for_dept|
            # Create a unique key for employee-department combination
            combination_key = "#{emp.id}_#{department.id}"

            # Only add if we haven't seen this combination before
            unless seen_combinations.include?(combination_key)
              seen_combinations.add(combination_key)
              # Use the first user_detail for this department (they should all be the same department)
              user_detail = user_details_for_dept.first
              @employee_department_entries << {
                employee: emp,
                department: department,
                user_detail: user_detail,
                l1_code: emp.l1_code,
                l1_name: emp.l1_employer_name,
                l2_code: emp.l2_code,
                l2_name: emp.l2_employer_name,
                l3_code: emp.l3_code,
                l3_name: emp.l3_employer_name
              }
            end
          end
        else
          combination_key = "#{emp.id}_default"

          unless seen_combinations.include?(combination_key)
            seen_combinations.add(combination_key)
            @employee_department_entries << {
              employee: emp,
              department: nil,
              user_detail: nil,
              l1_code: emp.l1_code,
              l1_name: emp.l1_employer_name,
              l2_code: emp.l2_code,
              l2_name: emp.l2_employer_name,
              l3_code: emp.l3_code,
              l3_name: emp.l3_employer_name
            }
          end
        end
      end

      @employee_department_entries = Kaminari.paginate_array(@employee_department_entries)
                                            .page(params[:page])
                                            .per(10)

      flash.now[:alert] = "Failed to create employee."
      render :index, status: :unprocessable_entity
    end
  end

  def update
    Rails.logger.info "UPDATE ACTION CALLED with params: #{params.inspect}"
    Rails.logger.info "Request method: #{request.method}"
    Rails.logger.info "Request path: #{request.path}"

    # Get department context if provided
    department_id = params[:employee_detail][:department_id] if params[:employee_detail].present?
    department = Department.find(department_id) if department_id.present?

    permitted_params = employee_detail_params

    # Handle department-specific updates
    if department.present?
      # Check if there's already a separate employee record for this department
      dept_employee = EmployeeDetail.joins(:user_details)
                                  .where(employee_code: "#{@employee_detail.employee_code}_#{department.id}")
                                  .where(user_details: { department: department })
                                  .first

      if dept_employee
        # Update the existing department-specific record
        if dept_employee.update(permitted_params)
          Rails.logger.info "Updated existing department-specific record for #{department.department_type}"
          redirect_to employee_details_path, notice: "Employee updated successfully for #{department.department_type} department."
        else
          Rails.logger.error "Update failed with errors: #{dept_employee.errors.full_messages}"
          render :edit, status: :unprocessable_entity
        end
      else
        # Create a new employee_detail record for this department
        new_employee_detail = EmployeeDetail.new(permitted_params)
        new_employee_detail.employee_code = "#{@employee_detail.employee_code}_#{department.id}"
        new_employee_detail.employee_name = @employee_detail.employee_name
        new_employee_detail.employee_email = @employee_detail.employee_email
        new_employee_detail.mobile_number = @employee_detail.mobile_number
        new_employee_detail.user = @employee_detail.user

        if new_employee_detail.save
          # Create user_detail linking to the new employee_detail and department
          new_employee_detail.user_details.create!(
            department: department,
            activity: @employee_detail.user_details.first&.activity || Activity.first
          )

          Rails.logger.info "Created new department-specific record for #{department.department_type}"
          redirect_to employee_details_path, notice: "Employee updated successfully for #{department.department_type} department."
        else
          Rails.logger.error "Create failed with errors: #{new_employee_detail.errors.full_messages}"
          render :edit, status: :unprocessable_entity
        end
      end
    else
      # Update the main employee_detail record (default behavior)
      if @employee_detail.update(permitted_params)

        redirect_to employee_details_path, notice: "Employee updated successfully."
      else
        Rails.logger.error "Update failed with errors: #{@employee_detail.errors.full_messages}"
        render :edit, status: :unprocessable_entity
      end
    end
  end

  def destroy
    begin
      @employee_detail.destroy

      # Check if the request came from L2 view and redirect appropriately
      if request.referer&.include?("/employee_details/l2")
        redirect_to l2_employee_details_path, notice: "Employee deleted successfully."
      else
        redirect_to employee_details_path, notice: "Employee deleted successfully."
      end
    rescue => e
      Rails.logger.error "Error deleting employee detail: #{e.message}"

      # Check if the request came from L2 view and redirect appropriately
      if request.referer&.include?("/employee_details/l2")
        redirect_to l2_employee_details_path, alert: "Failed to delete employee. Please try again."
      else
        redirect_to employee_details_path, alert: "Failed to delete employee. Please try again."
      end
    end
  end

  def export_xlsx
    employee_details = EmployeeDetail.includes(:user_details).all

    package = Axlsx::Package.new
    workbook = package.workbook

    workbook.add_worksheet(name: "Employees") do |sheet|
      sheet.add_row [
        "Name", "Email", "Employee Code", "Mobile Number", "Department"
      ]

      # Create unique employee-department entries for export
      employee_department_entries = []
      seen_combinations = Set.new

      employee_details.each do |emp|
        if emp.user_details.any?
          # If employee has user_details (multiple departments), show each unique department as separate entry
          # Group user_details by department to ensure we only get one entry per department
          emp.user_details.includes(:department).group_by(&:department).each do |department, user_details_for_dept|
            # Create a unique key for employee-department combination
            combination_key = "#{emp.id}_#{department.id}"

            # Only add if we haven't seen this combination before
            unless seen_combinations.include?(combination_key)
              seen_combinations.add(combination_key)
              employee_department_entries << {
                employee: emp,
                department: department,
                l1_code: emp.l1_code,
                l1_name: emp.l1_employer_name,
                l2_code: emp.l2_code,
                l2_name: emp.l2_employer_name,
                l3_code: emp.l3_code,
                l3_name: emp.l3_employer_name
              }
            end
          end
        else
          # If employee has no user_details, show with default department
          combination_key = "#{emp.id}_default"

          unless seen_combinations.include?(combination_key)
            seen_combinations.add(combination_key)
            employee_department_entries << {
              employee: emp,
              department: nil,
              l1_code: emp.l1_code,
              l1_name: emp.l1_employer_name,
              l2_code: emp.l2_code,
              l2_name: emp.l2_employer_name,
              l3_code: emp.l3_code,
              l3_name: emp.l3_employer_name
            }
          end
        end
      end

      employee_department_entries.each do |entry|
        sheet.add_row [
          entry[:employee].employee_name,
          entry[:employee].employee_email,
          entry[:employee].employee_code,
          entry[:employee].mobile_number,
          entry[:department]&.department_type || entry[:employee].department
        ]
      end
    end

    tempfile = Tempfile.new([ "employee_details", ".xlsx" ])
    package.serialize(tempfile.path)
    send_file tempfile.path, filename: "employee_details.xlsx", type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  def export_quarterly_xlsx
    selected_year = normalize_financial_year(params[:year])
    include_legacy_yearless_records = params[:year].blank? || selected_year == current_financial_year_label
    year_scope = lambda do |scope|
      if include_legacy_yearless_records
        scope.where("user_details.year = ? OR user_details.year IS NULL OR user_details.year = ''", selected_year)
      else
        scope.where(year: selected_year)
      end
    end

    employee_details = EmployeeDetail.includes(
      user_details: [
        :activity,
        :department,
        { achievements: :achievement_remark }
      ]
    ).joins(:user_details).merge(year_scope.call(UserDetail.all)).distinct

    package = Axlsx::Package.new
    workbook = package.workbook

    workbook.add_worksheet(name: "Quarterly Data") do |sheet|
      # Define styles
      header_style = workbook.styles.add_style(bg_color: "1F4E78", fg_color: "FFFFFF", b: true, alignment: { horizontal: :center })
      data_style = workbook.styles.add_style(alignment: { horizontal: :left })
      percentage_style = workbook.styles.add_style(alignment: { horizontal: :center })

      # Add header row as per user request
      sheet.add_row [
        "Financial Year", "Employee Code", "Employee Name", "Department", "Quarter", "Status",
        "L1 Name", "L1 Employee Code", "L1 Remarks", "L1 Percentage",
        "L2 Name", "L2 Employee Code", "L2 Remarks", "L2 Percentage",
        "L3 Name", "L3 Employee Code", "L3 Remarks", "L3 Percentage"
      ], style: header_style

      # Define quarters
      quarters = {
        "Q1" => [ "april", "may", "june", "q1" ],
        "Q2" => [ "july", "august", "september", "q2" ],
        "Q3" => [ "october", "november", "december", "q3" ],
        "Q4" => [ "january", "february", "march", "q4" ]
      }

      # Create unique employee-department entries for quarterly export
      employee_department_entries = []
      seen_combinations = Set.new

      employee_details.each do |emp|
        if emp.user_details.any?
          emp.user_details.includes(:department).group_by(&:department).each do |department, user_details_for_dept|
            next if department.nil?
            combination_key = "#{emp.id}_#{department.id}"
            filtered_user_details = year_scope.call(user_details_for_dept.is_a?(ActiveRecord::Relation) ? user_details_for_dept : UserDetail.where(id: user_details_for_dept.map(&:id)))
            next if filtered_user_details.blank?

            unless seen_combinations.include?(combination_key)
              seen_combinations.add(combination_key)
              employee_department_entries << {
                employee: emp,
                department: department,
                user_details: filtered_user_details.to_a
              }
            end
          end
        else
          combination_key = "#{emp.id}_default"
          unless seen_combinations.include?(combination_key)
            seen_combinations.add(combination_key)
            employee_department_entries << {
              employee: emp,
              department: nil,
              user_details: []
            }
          end
        end
      end

      # Process each employee-department entry and quarter
      employee_department_entries.each do |entry|
        emp = entry[:employee]
        quarters.each do |quarter_name, quarter_months|
          # Get achievements for this specific department
          all_quarter_achievements = entry[:user_details].flat_map(&:achievements).select { |ach| quarter_months.include?(ach.month&.downcase) }

          # Only add row if there are achievements in this quarter
          if all_quarter_achievements.any?
            # Get L1, L2 and L3 data from achievement remarks
            l1_remarks = []
            l1_percentages = []
            l2_remarks = []
            l2_percentages = []
            l3_remarks = []
            l3_percentages = []

            all_quarter_achievements.each do |achievement|
              if achievement.achievement_remark.present?
                l1_remarks << achievement.achievement_remark.l1_remarks if achievement.achievement_remark.l1_remarks.present?
                l1_percentages << achievement.achievement_remark.l1_percentage.to_f if achievement.achievement_remark.l1_percentage.present?
                l2_remarks << achievement.achievement_remark.l2_remarks if achievement.achievement_remark.l2_remarks.present?
                l2_percentages << achievement.achievement_remark.l2_percentage.to_f if achievement.achievement_remark.l2_percentage.present?
                l3_remarks << achievement.achievement_remark.l3_remarks if achievement.achievement_remark.l3_remarks.present?
                l3_percentages << achievement.achievement_remark.l3_percentage.to_f if achievement.achievement_remark.l3_percentage.present?
              end
            end

            # Calculate averages
            l1_avg = l1_percentages.any? ? (l1_percentages.sum / l1_percentages.size).round(1) : 0.0
            l2_avg = l2_percentages.any? ? (l2_percentages.sum / l2_percentages.size).round(1) : 0.0
            l3_avg = l3_percentages.any? ? (l3_percentages.sum / l3_percentages.size).round(1) : 0.0

            # Join remarks with semicolons
            l1_remarks_text = l1_remarks.uniq.join("; ")
            l2_remarks_text = l2_remarks.uniq.join("; ")
            l3_remarks_text = l3_remarks.uniq.join("; ")

            # Calculate correct status based on achievements in this quarter
            quarter_statuses = all_quarter_achievements.map { |ach| ach.status || "pending" }
            has_l1_approval = all_quarter_achievements.any? { |ach| ach.achievement_remark&.l1_percentage.present? }
            has_l2_approval = all_quarter_achievements.any? { |ach| ach.achievement_remark&.l2_percentage.present? }
            has_l3_approval = all_quarter_achievements.any? { |ach| ach.achievement_remark&.l3_percentage.present? }

            status_display = if quarter_statuses.any? { |s| s == "l3_returned" }
                              "L3 Returned"
            elsif quarter_statuses.all? { |s| s == "l3_approved" } || has_l3_approval
                              "L3 Approved"
            elsif quarter_statuses.any? { |s| s == "l2_returned" }
                              "L2 Returned"
            elsif quarter_statuses.all? { |s| s == "l2_approved" } || has_l2_approval
                              "L2 Approved"
            elsif quarter_statuses.any? { |s| s == "l1_returned" }
                              "L1 Returned"
            elsif quarter_statuses.all? { |s| s == "l1_approved" } || has_l1_approval
                              "L1 Approved"
            elsif quarter_statuses.any? { |s| [ "submitted", "pending" ].include?(s) }
                              "Submitted"
            else
                              "Pending"
            end

            sheet.add_row [
              selected_year,
              emp.employee_code || "N/A",
              emp.employee_name || "N/A",
              entry[:department]&.department_type || emp.department || "N/A",
              quarter_name,
              status_display,
              emp.l1_employer_name || "N/A",
              emp.l1_code || "N/A",
              l1_remarks_text.presence || "No Remarks",
              "#{l1_avg}%",
              emp.l2_employer_name || "N/A",
              emp.l2_code || "N/A",
              l2_remarks_text.presence || "No Remarks",
              "#{l2_avg}%",
              emp.l3_employer_name || "N/A",
              emp.l3_code || "N/A",
              l3_remarks_text.presence || "No Remarks",
              "#{l3_avg}%"
            ], style: [ data_style, data_style, data_style, data_style, data_style, data_style, data_style, data_style, data_style, percentage_style, data_style, data_style, data_style, percentage_style, data_style, data_style, data_style, percentage_style ]
          end
        end
      end

      # Auto-width for columns
      sheet.column_widths nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
    end

    tempfile = Tempfile.new([ "quarterly_l1_l2_data_#{selected_year.tr('-', '_')}", ".xlsx" ])
    package.serialize(tempfile.path)
    send_file tempfile.path, filename: "quarterly_l1_l2_data_#{selected_year}.xlsx", type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  def download_template
    package = Axlsx::Package.new
    workbook = package.workbook

    # Fetch all registered employees
    employee_details = EmployeeDetail.includes(user_details: :department).all

    workbook.add_worksheet(name: "Employee Template") do |sheet|
      # Header row
      sheet.add_row [
        "Name", "Email", "Employee Code", "Mobile Number",
        "L1 Code", "L1 Name", "L2 Code", "L2 Name",
        "L3 Code", "L3 Name", "Department"
      ]

      # Data rows — registered employees ka data
      employee_details.each do |emp|
        # Department fetch karo (pehle user_details se, warna emp.department)
        dept_name = emp.user_details.first&.department&.department_type || emp.department

        sheet.add_row [
          emp.employee_name,
          emp.employee_email,
          emp.employee_code,
          emp.mobile_number,
          emp.l1_code,
          emp.l1_employer_name,
          emp.l2_code,
          emp.l2_employer_name,
          emp.l3_code,
          emp.l3_employer_name,
          dept_name
        ]
      end
    end

    tempfile = Tempfile.new([ "employee_template", ".xlsx" ])
    package.serialize(tempfile.path)
    send_file tempfile.path,
              filename: "employee_template.xlsx",
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
              disposition: "attachment"
  end

  def import
    file = params[:file]

    if file.nil?
      redirect_to employee_details_path, alert: "Please upload a file."
      return
    end

    spreadsheet = Roo::Spreadsheet.open(file.path)
    header = spreadsheet.row(1)

    header_map = {
      "Name" => "employee_name",
      "Email" => "employee_email",
      "Employee Code" => "employee_code",
      "Mobile Number" => "mobile_number",
      "L1 Code" => "l1_code",
      "L2 Code" => "l2_code",
      "L3 Code" => "l3_code",
      "L1 Name" => "l1_employer_name",
      "L2 Name" => "l2_employer_name",
      "L3 Name" => "l3_employer_name",
      "Post" => "post",
      "Department" => "department"
    }

    imported_count = 0
    user_creation_results = { created: 0, existing: 0, errors: 0 }
    excel_data = []

    (2..spreadsheet.last_row).each do |i|
      row = Hash[[ header, spreadsheet.row(i) ].transpose]
      mapped_row = row.transform_keys { |key| header_map[key] }.compact

      begin
        employee_detail = EmployeeDetail.create!(mapped_row)
        imported_count += 1
        excel_data << mapped_row
      rescue => e
        puts "Import failed for row #{i}: #{e.message}"
        next
      end
    end

    # Create user accounts for imported employees
    if excel_data.any?
      user_results = UserCreationService.create_users_from_excel_data(excel_data)
      user_creation_results[:created] = user_results[:created].count
      user_creation_results[:existing] = user_results[:existing].count
      user_creation_results[:errors] = user_results[:errors].count
    end

    # Create success message
    success_message = "Excel file imported successfully! #{imported_count} records processed."
    if user_creation_results[:created] > 0
      success_message += " User accounts have been automatically created for all employees with default password '123456'."
    end
    if user_creation_results[:existing] > 0
      success_message += " #{user_creation_results[:existing]} user accounts already existed."
    end
    if user_creation_results[:errors] > 0
      success_message += " #{user_creation_results[:errors]} user accounts could not be created."
    end

    redirect_to employee_details_path, notice: success_message
  end

  # L1 Dashboard - Show quarterly data
  def l1
    authorize! :l1, EmployeeDetail

    # Get department filter parameter
    @selected_department = params[:department_filter]

    if current_user.hod?
      # HOD can see all employees with achievements
      all_employees = EmployeeDetail.includes(
        user_details: [
          :activity,
          :department,
          { achievements: :achievement_remark }
        ]
      ).where(
        id: scoped_user_details_for_year(UserDetail.joins(:achievements)).distinct.pluck(:employee_detail_id)
      )
    else
      # FIXED: L1 managers can see their assigned employees (with or without achievements)
      # First get all employees assigned to this L1 manager
      all_assigned_employees = EmployeeDetail
                                .for_l1_user(current_user.employee_code)
                                .includes(
                                  user_details: [
                                    :activity,
                                    :department,
                                    { achievements: :achievement_remark }
                                  ]
                                )

      # FIXED: Filter to show employees who have actually submitted quarterly achievement data
      all_employees = all_assigned_employees.select do |emp|
        # Only show employees who have submitted quarterly achievements (q1, q2, q3, q4) with actual data
        # Check if employee has quarterly achievements with meaningful data in any of their departments
        scoped_user_details_for_year(emp.user_details).any? do |ud|
          ud.achievements.any? do |ach|
            [ "q1", "q2", "q3", "q4" ].include?(ach.month) && ach.achievement.present?
          end
        end
      end
    end

    # Apply department filter if specified
    if @selected_department.present?
      all_employees = all_employees.joins(user_details: :department)
                                   .where(departments: { department_type: @selected_department })
    end

    # FIXED: For L1 view, show separate records for each department
    # Don't deduplicate by employee code - we want to show each department separately
    @employee_details = all_employees

    # Group employees by quarters for display
    @quarterly_data = group_employees_by_quarters(@employee_details)
  end

  # DYNAMIC STATUS UPDATE - AJAX endpoint for real-time status updates
  def get_status
    begin
      @employee_detail = EmployeeDetail.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Employee not found" }, status: :not_found
      return
    end

    authorize! :read, @employee_detail

    quarter = params[:quarter] || "Q1"
    department_id = params[:department_id]

    # Calculate status using same logic as show.html.erb
    quarter_months = case quarter
    when "Q1"
                       [ "april", "may", "june" ]
    when "Q2"
                       [ "july", "august", "september" ]
    when "Q3"
                       [ "october", "november", "december" ]
    when "Q4"
                       [ "january", "february", "march" ]
    else
                       []
    end

    # Get user details for this department
    if department_id.present?
      all_employee_records = EmployeeDetail.where(employee_name: @employee_detail.employee_name)
      user_details = []
      all_employee_records.each do |emp|
        scoped_user_details_for_department_and_year(
          emp.user_details.includes(:activity, :department, { achievements: :achievement_remark }),
          department_id
        ).each do |ud|
          user_details << ud
        end
      end
    else
      user_details = scoped_user_details_for_year(
        @employee_detail.user_details.includes(:activity, :department, { achievements: :achievement_remark })
      )
    end

    # Calculate status
    quarterly_statuses = []
    quarter_l1_total = 0
    quarter_remarks_l1 = Set.new

    user_details.each do |detail|
      # Include BOTH monthly and quarterly achievements for status calculation
      # Monthly achievements (april, may, june, etc.)
      monthly_achievements = detail.achievements.select { |a| quarter_months.include?(a.month) }

      # Quarterly achievements (q1, q2, q3, q4)
      quarterly_achievements = detail.achievements.select do |a|
        case quarter
        when "Q1"
          a.month == "q1"
        when "Q2"
          a.month == "q2"
        when "Q3"
          a.month == "q3"
        when "Q4"
          a.month == "q4"
        else
          false
        end
      end

      # Combine both types of achievements
      all_quarter_achievements = monthly_achievements + quarterly_achievements

      all_quarter_achievements.each do |achievement|
        status = achievement.status || "pending"
        quarterly_statuses << status

        if achievement.achievement_remark.present?
          if achievement.achievement_remark.l1_percentage.present?
            quarter_l1_total += achievement.achievement_remark.l1_percentage.to_f
          end
          if achievement.achievement_remark.l1_remarks.present?
            quarter_remarks_l1.add(achievement.achievement_remark.l1_remarks)
          end
        end
      end
    end

    # Apply EXACT same status logic as show.html.erb
    has_l1_remarks = quarter_remarks_l1.any? { |remark| remark.present? && remark != "No remarks for this quarter" }
    has_l1_percentage = quarter_l1_total > 0

    if quarterly_statuses.empty?
      status = "pending"
    elsif user_details.empty?
      status = "pending"
    elsif !has_l1_remarks && !has_l1_percentage
      status = "pending"
    else
      status = if quarterly_statuses.include?("returned_to_employee")
                "returned_to_employee"
      elsif quarterly_statuses.include?("l3_approved")
                "l3_approved"
      elsif quarterly_statuses.include?("l3_returned")
                "l3_returned"
      elsif quarterly_statuses.include?("l2_approved")
                "l2_approved"
      elsif quarterly_statuses.include?("l2_returned")
                "l2_returned"
      elsif quarterly_statuses.include?("l1_returned")
                "l1_returned"
      elsif quarterly_statuses.include?("l1_approved")
                "l1_approved"
      elsif quarterly_statuses.include?("submitted")
                "submitted"
      elsif quarterly_statuses.include?("pending")
                "pending"
      else
                "pending"
      end
    end

    render json: {
      status: status,
      employee_name: @employee_detail.employee_name,
      department_id: department_id,
      quarter: quarter,
      l1_remarks: has_l1_remarks,
      l1_percentage: quarter_l1_total
    }
  end

  # Show employee details with quarterly view
  def show
    begin
      @employee_detail = EmployeeDetail.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to l1_employee_details_path, alert: "❌ Employee detail not found. The record may have been deleted."
      return
    end

    authorize! :read, @employee_detail

    @user_detail_id = params[:user_detail_id]
    @selected_quarter = params[:quarter] || "Q2"  # Default to Q2
    @selected_department = params[:department_id]

    # FIXED: Get user details from ALL EmployeeDetail records for this employee, filtered by department
    if @selected_department.present?
      # Get all EmployeeDetail records for this employee (same employee name)
      all_employee_records = EmployeeDetail.where(employee_name: @employee_detail.employee_name)

      # Get all user_details from ALL employee records for this department
      @user_details = []
      all_employee_records.each do |emp|
        scoped_user_details_for_department_and_year(
          emp.user_details.includes(:activity, :department, { achievements: :achievement_remark }),
          @selected_department
        ).each do |ud|
          @user_details << ud
        end
      end
    else
      # Default to first department if no specific department selected
      first_user_detail = @employee_detail.user_details.joins(:department)
                                          .includes(:department)
                                          .first

      first_department = first_user_detail&.department

      if first_department
        # Get all EmployeeDetail records for this employee (same employee name)
        all_employee_records = EmployeeDetail.where(employee_name: @employee_detail.employee_name)

        # Get all user_details from ALL employee records for this department
        @user_details = []
        all_employee_records.each do |emp|
          scoped_user_details_for_department_and_year(
            emp.user_details.includes(:activity, :department, { achievements: :achievement_remark }),
            first_department.id
          ).each do |ud|
            @user_details << ud
          end
        end
        @selected_department = first_department.id
      else
        # Fallback to all user details if no departments found
        @user_details = @employee_detail.user_details
                          .then { |scope| scoped_user_details_for_year(scope.includes(:activity, :department, { achievements: :achievement_remark })) }
      end
    end

    # If quarter is selected, filter achievements by quarter
    if @selected_quarter.present?
      @quarterly_activities = get_quarterly_activities(@user_details, @selected_quarter)
    else
      @quarterly_activities = get_all_quarterly_activities(@user_details)
    end

    @can_approve_or_return = can_act_as_l1?(@employee_detail)
  end

  # Edit employee details with department context
  def edit
    begin
      @employee_detail = EmployeeDetail.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to employee_details_path, alert: "❌ Employee detail not found. The record may have been deleted."
      return
    end

    authorize! :update, @employee_detail

    # Get department context if provided
    @department_id = params[:department_id]
    @department = Department.find(@department_id) if @department_id.present?

    # Check if this is a department-specific edit and if there's a separate record
    if @department.present?
      dept_employee = EmployeeDetail.joins(:user_details)
                                  .where(employee_code: "#{@employee_detail.employee_code}_#{@department.id}")
                                  .where(user_details: { department: @department })
                                  .first

      if dept_employee
        # Use the department-specific employee record
        @employee_detail = dept_employee
      end
    end

    # Use the current L1/L2/L3 values from the employee_detail record
    # These will be the values that were last saved for this employee
    @l1_code = @employee_detail.l1_code
    @l1_name = @employee_detail.l1_employer_name
    @l2_code = @employee_detail.l2_code
    @l2_name = @employee_detail.l2_employer_name
    @l3_code = @employee_detail.l3_code
    @l3_name = @employee_detail.l3_employer_name
  end

  # Quarterly approval - approve all activities for a quarter
  def approve
    Rails.logger.info "L1 APPROVE ACTION CALLED for employee: #{params[:id]}, user: #{current_user.email}, params: #{params.inspect}"
    Rails.logger.info "Request method: #{request.method}"
    Rails.logger.info "Request path: #{request.path}"

    begin
      @employee_detail = EmployeeDetail.find(params[:id])
      Rails.logger.info "Employee detail found: #{@employee_detail.id}, L1 code: #{@employee_detail.l1_code}, L1 employer: #{@employee_detail.l1_employer_name}"
    rescue ActiveRecord::RecordNotFound
      if request.xhr?
        render json: { success: false, message: "❌ Employee detail not found. The record may have been deleted." }, status: :not_found
      else
        redirect_to employee_details_path, alert: "❌ Employee detail not found. The record may have been deleted."
      end
      return
    end

    # Skip authorization check for AJAX requests to prevent CanCan errors
    if request.xhr? || params[:action_type].present?
      # For AJAX requests, we'll handle authorization in the processing method
    else
      unless can_act_as_l1?(@employee_detail)
        redirect_back fallback_location: root_path, alert: "❌ You are not authorized to approve this record"
        return
      end
    end

    if can_act_as_l1?(@employee_detail)
      # Pass action_type parameter to indicate this is an approval action
      params[:action_type] = "approve"
      result = process_quarterly_l1_approval

      if result[:success]
        # FIXED: Department-wise success message
        department_info = if params[:department_id].present?
          department = Department.find(params[:department_id])
          " for #{department.department_type} department"
        else
          " for all departments"
        end

        if request.xhr? || params[:action_type].present?
          render json: {
            success: true,
            count: result[:count],
            message: "✅ Successfully approved #{result[:count]} activities#{department_info} for #{params[:selected_quarter] || 'all quarters'} by L1",
            updated_status: "l1_approved"
          }
        else
          redirect_to employee_detail_path(@employee_detail, quarter: params[:selected_quarter], department_id: params[:department_id]),
                      notice: "✅ Successfully approved #{result[:count]} activities#{department_info} for #{params[:selected_quarter] || 'all quarters'} by L1"
        end
      else
        if request.xhr? || params[:action_type].present?
          render json: { success: false, message: result[:message] }, status: :unprocessable_entity
        else
          redirect_back fallback_location: root_path, alert: result[:message]
        end
      end

    elsif can_act_as_l2?(@employee_detail)
      # Pass action_type parameter to indicate this is an approval action
      params[:action_type] = "approve"
      result = process_quarterly_l2_approval

      if result[:success]
        if request.xhr? || params[:action_type].present?
          render json: {
            success: true,
            count: result[:count],
            message: "✅ Successfully approved #{result[:count]} activities for #{params[:selected_quarter] || 'all quarters'} by L2"
          }
        else
          redirect_to employee_detail_path(@employee_detail, quarter: params[:selected_quarter]),
                      notice: "✅ Successfully approved #{result[:count]} activities for #{params[:selected_quarter] || 'all quarters'} by L2"
        end
      else
        if request.xhr? || params[:action_type].present?
          render json: { success: false, message: result[:message] }
        else
          redirect_back fallback_location: root_path, alert: result[:message]
        end
      end
    else
      if request.xhr? || params[:action_type].present?
        render json: { success: false, message: "❌ You are not authorized to approve this record" }
      else
        redirect_back fallback_location: root_path, alert: "❌ You are not authorized to approve this record"
      end
    end
  end

  # Quarterly return - return all activities for a quarter
  def return
    Rails.logger.info "L1 RETURN ACTION CALLED for employee: #{params[:id]}, user: #{current_user.email}, params: #{params.inspect}"

    begin
      @employee_detail = EmployeeDetail.find(params[:id])
      Rails.logger.info "Employee detail found: #{@employee_detail.id}, L1 code: #{@employee_detail.l1_code}, L1 employer: #{@employee_detail.l1_employer_name}"
    rescue ActiveRecord::RecordNotFound
      if request.xhr?
        render json: { success: false, message: "❌ Employee detail not found. The record may have been deleted." }, status: :not_found
      else
        redirect_to employee_details_path, alert: "❌ Employee detail not found. The record may have been deleted."
      end
      return
    end

    # Skip authorization check for AJAX requests to prevent CanCan errors
    if request.xhr? || params[:action_type].present?
      # For AJAX requests, we'll handle authorization in the processing method
    else
      unless can_act_as_l1?(@employee_detail)
        redirect_back fallback_location: root_path, alert: "❌ You are not authorized to return this record"
        return
      end
    end

    if can_act_as_l1?(@employee_detail)
      # Pass action_type parameter to indicate this is a return action
      params[:action_type] = "return"
      result = process_quarterly_l1_return

      if result[:success]
        # FIXED: Department-wise success message for return
        department_info = if params[:department_id].present?
          department = Department.find(params[:department_id])
          " for #{department.department_type} department"
        else
          " for all departments"
        end

        if request.xhr? || params[:action_type].present?
          render json: {
            success: true,
            count: result[:count],
            message: "⚠️ Successfully returned #{result[:count]} activities#{department_info} for #{params[:selected_quarter] || 'all quarters'} by L1",
            updated_status: "l1_returned"
          }
        else
          redirect_to employee_detail_path(@employee_detail, quarter: params[:selected_quarter], department_id: params[:department_id]),
                      alert: "⚠️ Successfully returned #{result[:count]} activities#{department_info} for #{params[:selected_quarter] || 'all quarters'} by L1"
        end
      else
        if request.xhr? || params[:action_type].present?
          render json: { success: false, message: result[:message] }, status: :unprocessable_entity
        else
          redirect_back fallback_location: root_path, alert: result[:message]
        end
      end

    elsif can_act_as_l2?(@employee_detail)
      # Pass action_type parameter to indicate this is a return action
      params[:action_type] = "return"
      result = process_quarterly_l2_return

      if result[:success]
        if request.xhr? || params[:action_type].present?
          render json: {
            success: true,
            count: result[:count],
            message: "⚠️ Successfully returned #{result[:count]} activities for #{params[:selected_quarter] || 'all quarters'} by L2"
          }
        else
          redirect_to employee_detail_path(@employee_detail, quarter: params[:selected_quarter]),
                      alert: "⚠️ Successfully returned #{result[:count]} activities for #{params[:selected_quarter] || 'all quarters'} by L2"
        end
      else
        if request.xhr? || params[:action_type].present?
          render json: { success: false, message: result[:message] }
        else
          redirect_back fallback_location: root_path, alert: result[:message]
        end
      end
    else
      if request.xhr? || params[:action_type].present?
        render json: { success: false, message: "❌ You are not authorized to return this record" }
      else
        redirect_back fallback_location: root_path, alert: result[:message]
      end
    end
  end

def l2
  # Get department filter parameter
  @selected_department = params[:department_filter]

  if current_user.hod?
    # HOD can see all employee details, but only those with L1+ approved achievements
    all_employees = EmployeeDetail.includes(
      user_details: [
        :activity,
        :department,
        { achievements: :achievement_remark }
      ]
    ).order(created_at: :desc)
  else
      # L2 managers can only see their assigned employees with L1 approved achievements (pending L2 review)
      # FIXED: Get all EmployeeDetail records for employees assigned to this L2 manager with proper associations
      l2_employee_codes = EmployeeDetail.for_l2_user(current_user.employee_code).pluck(:employee_code)
      all_employees = EmployeeDetail.where(employee_code: l2_employee_codes)
                                     .includes(
                                       user_details: [
                                         :activity,
                                         :department,
                                         { achievements: :achievement_remark }
                                       ]
                                     )
                                     .order(created_at: :desc)
  end

  # Apply department filter if specified
  if @selected_department.present?
    all_employees = all_employees.joins(user_details: :department)
                                 .where(departments: { department_type: @selected_department })
  end

  # Filter to include employees who have L1 approved achievements (ready for L2 review)
  # L2 view should show:
  # 1. L1 approved records (ready for L2 review)
  # 2. L2 approved records (L2 has acted, but should still show on L2 page)
  # 3. L3 approved/returned records (L3 has acted, but should still show on L2 page)
  # CRITICAL: Only show records where L1 has actually approved (workflow hierarchy)
  filtered_employees = all_employees.select do |emp|
    Rails.logger.info "L2 Controller: Checking employee #{emp.employee_name}"
    has_qualifying_achievements = scoped_user_details_for_year(emp.user_details).any? do |ud|
      # Apply department filter at user_detail level if specified
      if @selected_department.present?
        next unless ud.department&.department_type == @selected_department
      end

      # Check each quarter to ensure L1 has approved before L2 can see it
      quarters = {
        "Q1" => [ "april", "may", "june" ],
        "Q2" => [ "july", "august", "september" ],
        "Q3" => [ "october", "november", "december" ],
        "Q4" => [ "january", "february", "march" ]
      }

      quarters.any? do |quarter_name, quarter_months|
        # Get all achievements for this quarter
        quarter_achievements = ud.achievements.select do |achievement|
          (quarter_months.include?(achievement.month) ||
           (quarter_name == "Q1" && achievement.month == "q1") ||
           (quarter_name == "Q2" && achievement.month == "q2") ||
           (quarter_name == "Q3" && achievement.month == "q3") ||
           (quarter_name == "Q4" && achievement.month == "q4"))
        end

        # Skip if no achievements for this quarter
        next if quarter_achievements.empty?

        # Show this quarter if it has achievements that L2 should see:
        # CRITICAL: L2 can ONLY see records that have been L1 approved
        # Check if this specific department/quarter has been L1 approved (same logic as L1 view)

        # First check if L1 has provided remarks and percentage (same as L1 view logic)
        quarter_l1_total = 0
        quarter_remarks_l1 = Set.new

        quarter_achievements.each do |achievement|
          if achievement.achievement_remark.present?
            # Collect L1 data
            if achievement.achievement_remark.l1_percentage.present?
              quarter_l1_total += achievement.achievement_remark.l1_percentage.to_f
            end

            # Add unique L1 remarks only
            if achievement.achievement_remark.l1_remarks.present?
              quarter_remarks_l1.add(achievement.achievement_remark.l1_remarks)
            end
          end
        end

        has_l1_remarks = quarter_remarks_l1.any? { |remark| remark.present? && remark != "No remarks for this quarter" }
        has_l1_percentage = quarter_l1_total > 0

        # CRITICAL: Only show records that have been L1 approved (workflow hierarchy)
        # L2 cannot see records that are still pending L1 approval
        # Check if this specific department/quarter combination has been L1 approved
        has_l1_approved = quarter_achievements.any? { |ach| ach.status == "l1_approved" }
        has_l2_approved = quarter_achievements.any? { |ach| ach.status == "l2_approved" }
        has_l2_returned = quarter_achievements.any? { |ach| ach.status == "l2_returned" }
        has_l3_approved = quarter_achievements.any? { |ach| ach.status == "l3_approved" }
        has_l3_returned = quarter_achievements.any? { |ach| ach.status == "l3_returned" }
        
        # FIXED: Also show in L2 view if it was returned to employee by L2 or L3
        has_returned_to_employee = quarter_achievements.any? { |ach| ach.status == "returned_to_employee" }
        returned_by_l2_or_l3 = quarter_achievements.any? { |a| a.achievement_remark&.l2_remarks.present? || a.achievement_remark&.l3_remarks.present? }

        # Only show if L1 has actually approved (provided remarks/percentage) OR if it's already been processed by L2/L3
        has_ready_for_l2 = (has_l1_remarks || has_l1_percentage) && (has_l1_approved || has_l2_approved || has_l2_returned || has_l3_approved || has_l3_returned || (has_returned_to_employee && returned_by_l2_or_l3))

        # Show this quarter if achievements are ready for L2
        has_ready_for_l2
      end
    end
    has_qualifying_achievements
  end

  # FIXED: Don't deduplicate employees - show separate records for each department with L1 approved achievements
  # This allows the same employee to appear multiple times if they have L1 approved achievements in different departments
  @employee_details = filtered_employees
end

  def show_l2
    begin
      @employee_detail = EmployeeDetail.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to l2_employee_details_path, alert: "❌ Employee detail not found. The record may have been deleted."
      return
    end

    unless current_user.hod? || can_act_as_l2?(@employee_detail)
      redirect_to l2_employee_details_path, alert: "❌ You are not authorized to access this page."
      return
    end

    @user_detail_id = params[:user_detail_id]
    @selected_quarter = params[:quarter] || "Q2"  # Default to Q2
    @selected_department = params[:department_id]

    # FIXED: Get user details from ALL EmployeeDetail records for this employee, filtered by department
    if @selected_department.present?
      # Get all EmployeeDetail records for this employee (same employee name)
      all_employee_records = EmployeeDetail.where(employee_name: @employee_detail.employee_name)

      # Get all user_details from ALL employee records for this department
      @user_details = []
      all_employee_records.each do |emp|
        scoped_user_details_for_department_and_year(
          emp.user_details.includes(:activity, :department, { achievements: :achievement_remark }),
          @selected_department
        ).each do |ud|
          @user_details << ud
        end
      end
    else
      # Default to first department if no specific department selected
      first_user_detail = @employee_detail.user_details.joins(:department)
                                          .includes(:department)
                                          .first

      first_department = first_user_detail&.department

      if first_department
        # Get all EmployeeDetail records for this employee (same employee name)
        all_employee_records = EmployeeDetail.where(employee_name: @employee_detail.employee_name)

        # Get all user_details from ALL employee records for this department
        @user_details = []
        all_employee_records.each do |emp|
          scoped_user_details_for_department_and_year(
            emp.user_details.includes(:activity, :department, { achievements: :achievement_remark }),
            first_department.id
          ).each do |ud|
            @user_details << ud
          end
        end
        @selected_department = first_department.id
      else
        # Fallback to all user details if no departments found
        @user_details = @employee_detail.user_details
                          .then { |scope| scoped_user_details_for_year(scope.includes(:activity, :department, { achievements: :achievement_remark })) }
      end
    end

    # If quarter is selected, filter achievements by quarter
    if @selected_quarter.present?
      @quarterly_activities = get_quarterly_activities(@user_details, @selected_quarter)
    else
      @quarterly_activities = get_all_quarterly_activities(@user_details)
    end

    @can_l2_approve_or_return = can_act_as_l2?(@employee_detail)
    @can_l2_act = @can_l2_approve_or_return
  end

  def l2_approve
    Rails.logger.info "L2 Approve called for employee: #{params[:id]}, user: #{current_user.email}, params: #{params.inspect}"

    begin
      @employee_detail = EmployeeDetail.find(params[:id])
      Rails.logger.info "Employee detail found: #{@employee_detail.id}, L2 code: #{@employee_detail.l2_code}, L2 employer: #{@employee_detail.l2_employer_name}"
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error "Employee detail not found: #{params[:id]}"
      if request.xhr?
        render json: { success: false, message: "❌ Employee detail not found. The record may have been deleted." }, status: :not_found
      else
        redirect_to employee_details_path, alert: "❌ Employee detail not found. The record may have been deleted."
      end
      return
    end

    # Skip authorization check for AJAX requests to prevent CanCan errors
    if request.xhr? || params[:action_type].present?
      # For AJAX requests, we'll handle authorization in the processing method
    else
      unless current_user.hod? || can_act_as_l2?(@employee_detail)
        redirect_to show_l2_employee_detail_path(@employee_detail), alert: "❌ You are not authorized to approve at L2 level"
        return
      end
    end

    # Pass action_type parameter to indicate this is an approval action
    params[:action_type] = "approve"
    result = process_quarterly_l2_approval

    if result[:success]
      if request.xhr? || params[:action_type].present?
        render json: {
          success: true,
          count: result[:count],
          message: "✅ Successfully approved #{result[:count]} activities for #{params[:selected_quarter] || 'all quarters'} by L2",
          updated_status: "l2_approved"
        }
      else
        redirect_to show_l2_employee_detail_path(@employee_detail, quarter: params[:selected_quarter]),
                    notice: "✅ Successfully approved #{result[:count]} activities for #{params[:selected_quarter] || 'all quarters'} by L2"
      end
    else
      if request.xhr? || params[:action_type].present?
        render json: { success: false, message: result[:message] }, status: :unprocessable_entity
      else
        redirect_to show_l2_employee_detail_path(@employee_detail, quarter: params[:selected_quarter]),
                    alert: result[:message]
      end
    end
  end

  def l2_return
    Rails.logger.info "L2 Return called for employee: #{params[:id]}, user: #{current_user.email}, params: #{params.inspect}"

    begin
      @employee_detail = EmployeeDetail.find(params[:id])
      Rails.logger.info "Employee detail found: #{@employee_detail.id}, L2 code: #{@employee_detail.l2_code}, L2 employer: #{@employee_detail.l2_employer_name}"
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error "Employee detail not found: #{params[:id]}"
      if request.xhr?
        render json: { success: false, message: "❌ Employee detail not found. The record may have been deleted." }, status: :not_found
      else
        redirect_to employee_details_path, alert: "❌ Employee detail not found. The record may have been deleted."
      end
      return
    end

    # Skip authorization check for AJAX requests to prevent CanCan errors
    if request.xhr? || params[:action_type].present?
      # For AJAX requests, we'll handle authorization in the processing method
    else
      unless current_user.hod? || can_act_as_l2?(@employee_detail)
        redirect_to show_l2_employee_detail_path(@employee_detail), alert: "❌ You are not authorized to return at L2 level"
        return
      end
    end


    # Pass action_type parameter to indicate this is a return action
    params[:action_type] = "return"
    result = process_quarterly_l2_return

    Rails.logger.info "L2 Return result: #{result.inspect}"

    if result[:success]
      if request.xhr? || params[:action_type].present?
        render json: {
          success: true,
          count: result[:count],
          message: "⚠️ Successfully returned #{result[:count]} activities for #{params[:selected_quarter] || 'all quarters'} by L2",
          updated_status: "l2_returned"
        }
      else
        redirect_to show_l2_employee_detail_path(@employee_detail, quarter: params[:selected_quarter]),
                    notice: "⚠️ Successfully returned #{result[:count]} activities for #{params[:selected_quarter] || 'all quarters'} by L2"
      end
    else
      if request.xhr? || params[:action_type].present?
        render json: { success: false, message: result[:message] }, status: :unprocessable_entity
      else
        redirect_to show_l2_employee_detail_path(@employee_detail, quarter: params[:selected_quarter]),
                    alert: result[:message]
      end
    end
  end

  # L3 Dashboard - Show only L2 approved records
  def l3
    if current_user.hod?
      # HOD can see all employee details, but only those with L2 approved achievements
      all_employees = EmployeeDetail.includes(
        user_details: [
          :activity,
          :department,
          { achievements: :achievement_remark }
        ]
      ).joins(:user_details).merge(scoped_user_details_for_year(UserDetail.all)).order(created_at: :desc)
    else
      # L3 managers can only see their assigned employees with L2 approved achievements
      # FIXED: Get all EmployeeDetail records for employees assigned to this L3 manager
      l3_employee_codes = EmployeeDetail.for_l3_user(current_user.employee_code).pluck(:employee_code)
      all_employees = EmployeeDetail.where(employee_code: l3_employee_codes)
                                     .order(created_at: :desc)
    end

    # Filter to include employees who have L2 approved, L3 approved, or L3 returned achievements
    # L3 view should show L2 approved (ready for L3 review), L3 approved, L3 returned, or returned to employee by L3
    filtered_employees = all_employees.select do |emp|
      has_qualifying_achievements = scoped_user_details_for_year(emp.user_details).any? do |ud|
        # Show employees with L2 approved, L3 approved, L3 returned, or returned to employee by L3
        qualifying_achievements = ud.achievements.select do |achievement|
          # Must be L2 approved, L3 approved, L3 returned, or returned_to_employee by L3 AND have quarterly data
          (achievement.status == "l2_approved" || achievement.status == "l3_approved" || achievement.status == "l3_returned" || (achievement.status == "returned_to_employee" && achievement.achievement_remark&.l3_remarks.present?)) &&
          ([ "april", "may", "june", "july", "august", "september", "october", "november", "december", "january", "february", "march" ].include?(achievement.month) ||
           [ "q1", "q2", "q3", "q4" ].include?(achievement.month))
        end
        qualifying_achievements.any?
      end
      has_qualifying_achievements
    end

    # FIXED: Don't deduplicate employees - show separate records for each department with L2/L3 approved/returned achievements
    # This allows the same employee to appear multiple times if they have achievements in different departments
    @employee_details = filtered_employees
  end

  def show_l3
    begin
      Rails.logger.info "Show L3: Looking for EmployeeDetail with ID: #{params[:id]}"
      @employee_detail = EmployeeDetail.find(params[:id])
      Rails.logger.info "Show L3: Found EmployeeDetail: #{@employee_detail.employee_name} (#{@employee_detail.employee_code})"
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Show L3: EmployeeDetail not found with ID: #{params[:id]} - #{e.message}"
      redirect_to l3_employee_details_path, alert: "❌ Employee detail not found. The record may have been deleted."
      return
    end

    unless current_user.hod? || can_act_as_l3?(@employee_detail)
      redirect_to l3_employee_details_path, alert: "❌ You are not authorized to access this page."
      return
    end

    @user_detail_id = params[:user_detail_id]
    @selected_quarter = params[:quarter] || "Q2"  # Default to Q2
    @selected_department = params[:department_id]

    # FIXED: Get user details from ALL EmployeeDetail records for this employee, filtered by department
    if @selected_department.present?
      # Get all EmployeeDetail records for this employee (same employee name)
      all_employee_records = EmployeeDetail.where(employee_name: @employee_detail.employee_name)

      # Get all user_details from ALL employee records for this department
      @user_details = []
      all_employee_records.each do |emp|
        scoped_user_details_for_department_and_year(
          emp.user_details.includes(:activity, :department, { achievements: :achievement_remark }),
          @selected_department
        ).each do |ud|
          @user_details << ud
        end
      end
    else
      # Default to first department if no specific department selected
      first_user_detail = @employee_detail.user_details.joins(:department)
                                          .includes(:department)
                                          .first

      first_department = first_user_detail&.department

      if first_department
        # Get all EmployeeDetail records for this employee (same employee name)
        all_employee_records = EmployeeDetail.where(employee_name: @employee_detail.employee_name)

        # Get all user_details from ALL employee records for this department
        @user_details = []
        all_employee_records.each do |emp|
          scoped_user_details_for_department_and_year(
            emp.user_details.includes(:activity, :department, { achievements: :achievement_remark }),
            first_department.id
          ).each do |ud|
            @user_details << ud
          end
        end
        @selected_department = first_department.id
      else
        # Fallback to all user details if no departments found
        @user_details = @employee_detail.user_details
                          .then { |scope| scoped_user_details_for_year(scope.includes(:activity, :department, { achievements: :achievement_remark })) }
      end
    end

    # If quarter is selected, filter achievements by quarter
    if @selected_quarter.present?
      @quarterly_activities = get_quarterly_activities(@user_details, @selected_quarter)
    else
      @quarterly_activities = get_all_quarterly_activities(@user_details)
    end

    @can_l3_approve_or_return = can_act_as_l3?(@employee_detail)
    @can_l3_act = @can_l3_approve_or_return
  end

  def l3_approve
    Rails.logger.info "L3 Approve called for employee: #{params[:id]}, user: #{current_user.email}, params: #{params.inspect}"
    Rails.logger.info "Request method: #{request.method}, XHR: #{request.xhr?}, Action type: #{params[:action_type]}"

    # Enhanced debugging for employee detail lookup
    employee_id = params[:id]
    Rails.logger.info "Looking for employee detail with ID: #{employee_id}"

    # Check if employee detail exists
    if employee_id.blank?
      Rails.logger.error "Employee ID is blank in params: #{params.inspect}"
      if request.xhr?
        render json: { success: false, message: "❌ Employee ID is missing from request." }, status: :bad_request
      else
        redirect_to employee_details_path, alert: "❌ Employee ID is missing from request."
      end
      return
    end

    begin
      @employee_detail = EmployeeDetail.find(employee_id)
      Rails.logger.info "Employee detail found: #{@employee_detail.id}, L3 code: #{@employee_detail.l3_code}, L3 employer: #{@employee_detail.l3_employer_name}"
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Employee detail not found: #{employee_id} - #{e.message}"
      Rails.logger.error "Available employee details: #{EmployeeDetail.pluck(:id, :employee_code).inspect}"

      if request.xhr?
        render json: { success: false, message: "❌ Employee detail not found. The record may have been deleted." }, status: :not_found
      else
        redirect_to employee_details_path, alert: "❌ Employee detail not found. The record may have been deleted."
      end
      return
    end

    # Skip authorization check for AJAX requests to prevent CanCan errors
    if request.xhr? || params[:action_type].present?
      # For AJAX requests, we'll handle authorization in the processing method
    else
      unless current_user.hod? || can_act_as_l3?(@employee_detail)
        redirect_to show_l3_employee_detail_path(@employee_detail), alert: "❌ You are not authorized to approve at L3 level"
        return
      end
    end

    # Pass action_type parameter to indicate this is an approval action
    params[:action_type] = "approve"
    result = process_quarterly_l3_approval

    if result[:success]
      if request.xhr? || params[:action_type].present?
        render json: {
          success: true,
          count: result[:count],
          message: "✅ Successfully approved #{result[:count]} activities for #{params[:selected_quarter] || 'all quarters'} by L3",
          updated_status: "l3_approved"
        }
      else
        redirect_to show_l3_employee_detail_path(@employee_detail, quarter: params[:selected_quarter]),
                    notice: "✅ Successfully approved #{result[:count]} activities for #{params[:selected_quarter] || 'all quarters'} by L3"
      end
    else
      if request.xhr? || params[:action_type].present?
        render json: { success: false, message: result[:message] }, status: :unprocessable_entity
      else
        redirect_to show_l3_employee_detail_path(@employee_detail, quarter: params[:selected_quarter]),
                    alert: result[:message]
      end
    end
  end

  def l3_return
    Rails.logger.info "L3 Return called for employee: #{params[:id]}, user: #{current_user.email}, params: #{params.inspect}"

    begin
      @employee_detail = EmployeeDetail.find(params[:id])
      Rails.logger.info "Employee detail found: #{@employee_detail.id}, L3 code: #{@employee_detail.l3_code}, L3 employer: #{@employee_detail.l3_employer_name}"
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error "Employee detail not found: #{params[:id]}"
      if request.xhr?
        render json: { success: false, message: "❌ Employee detail not found. The record may have been deleted." }, status: :not_found
      else
        redirect_to employee_details_path, alert: "❌ Employee detail not found. The record may have been deleted."
      end
      return
    end

    # Skip authorization check for AJAX requests to prevent CanCan errors
    if request.xhr? || params[:action_type].present?
      # For AJAX requests, we'll handle authorization in the processing method
    else
      unless current_user.hod? || can_act_as_l3?(@employee_detail)
        redirect_to show_l3_employee_detail_path(@employee_detail), alert: "❌ You are not authorized to return at L3 level"
        return
      end
    end


    # Pass action_type parameter to indicate this is a return action
    params[:action_type] = "return"
    result = process_quarterly_l3_approval

    Rails.logger.info "L3 Return result: #{result.inspect}"

    if result[:success]
      if request.xhr? || params[:action_type].present?
        render json: {
          success: true,
          count: result[:count],
          message: "⚠️ Successfully returned #{result[:count]} activities for #{params[:selected_quarter] || 'all quarters'} by L3",
          updated_status: "l3_returned"
        }
      else
        redirect_to show_l3_employee_detail_path(@employee_detail, quarter: params[:selected_quarter]),
                    notice: "⚠️ Successfully returned #{result[:count]} activities for #{params[:selected_quarter] || 'all quarters'} by L3"
      end
    else
      if request.xhr? || params[:action_type].present?
        render json: { success: false, message: result[:message] }, status: :unprocessable_entity
      else
        redirect_to show_l3_employee_detail_path(@employee_detail, quarter: params[:selected_quarter]),
                    alert: result[:message]
      end
    end
  end

  def edit_l1
    Rails.logger.info "L1 Edit called for employee: #{params[:id]}, user: #{current_user.email}, params: #{params.inspect}"

    begin
      @employee_detail = EmployeeDetail.find(params[:id])
      Rails.logger.info "Employee detail found: #{@employee_detail.id}"
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error "Employee detail not found: #{params[:id]}"
      if request.xhr?
        render json: { success: false, message: "❌ Employee detail not found. The record may have been deleted." }, status: :not_found
      else
        redirect_to employee_details_path, alert: "❌ Employee detail not found. The record may have been deleted."
      end
      return
    end

    # Check authorization - only L1 managers can edit L1 details when L2 has returned
    unless current_user.hod? || can_act_as_l1?(@employee_detail)
      if request.xhr?
        render json: { success: false, message: "❌ You are not authorized to edit L1 details" }, status: :forbidden
      else
        redirect_to employee_detail_path(@employee_detail), alert: "❌ You are not authorized to edit L1 details"
      end
      return
    end

    # Validate required parameters
    unless params[:l1_percentage].present? && params[:l1_remarks].present?
      if request.xhr?
        render json: { success: false, message: "❌ L1 percentage and remarks are required" }, status: :unprocessable_entity
      else
        redirect_to employee_detail_path(@employee_detail), alert: "❌ L1 percentage and remarks are required"
      end
      return
    end

    begin
      # Get the selected quarter
      selected_quarter = params[:selected_quarter]
      quarter_months = case selected_quarter
      when "Q1"
                        [ "april", "may", "june" ]
      when "Q2"
                        [ "july", "august", "september" ]
      when "Q3"
                        [ "october", "november", "december" ]
      when "Q4"
                        [ "january", "february", "march" ]
      else
                        []
      end

      # Get the department_id from params
      department_id = params[:department_id]

      # FIXED: Filter by department to only update achievements for the specific department
      # Find all achievements for the quarter that have L2 returned status
      updated_count = 0

      # Get all EmployeeDetail records for this employee (same employee name)
      all_employee_records = EmployeeDetail.where(employee_name: @employee_detail.employee_name)

      all_employee_records.each do |emp|
        emp.user_details.each do |user_detail|
          # FIXED: Only process user_details for the specific department
          next if department_id.present? && user_detail.department_id.to_s != department_id.to_s

          quarter_achievements = user_detail.achievements.select { |a| quarter_months.include?(a.month) }

          quarter_achievements.each do |achievement|
            # Update achievements that are in l2_returned, l3_returned, or l1_returned status
            if achievement.status == "l2_returned" || achievement.status == "l3_returned" || achievement.status == "l1_returned"
              # Find or create achievement remark
              achievement_remark = achievement.achievement_remark || achievement.build_achievement_remark

              # Update L1 data
              achievement_remark.l1_percentage = params[:l1_percentage].to_f
              achievement_remark.l1_remarks = params[:l1_remarks]
              achievement_remark.save!

              # Update achievement status to l1_approved since L1 has edited and approved
              achievement.update!(status: "l1_approved")

              updated_count += 1
            end
          end
        end
      end

      Rails.logger.info "L1 Edit completed: #{updated_count} achievements updated"

      if request.xhr?
        render json: {
          success: true,
          count: updated_count,
          message: "✅ Successfully updated L1 details for #{updated_count} activities in #{selected_quarter} quarter",
          updated_status: "l1_approved"
        }
      else
        redirect_to employee_detail_path(@employee_detail, quarter: selected_quarter),
                    notice: "✅ Successfully updated L1 details for #{updated_count} activities in #{selected_quarter} quarter"
      end

    rescue => e
      Rails.logger.error "Error in L1 Edit: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      if request.xhr?
        render json: { success: false, message: "❌ An error occurred while updating L1 details: #{e.message}" }, status: :internal_server_error
      else
        redirect_to employee_detail_path(@employee_detail), alert: "❌ An error occurred while updating L1 details: #{e.message}"
      end
    end
  end

  def edit_l2
    Rails.logger.info "L2 Edit called for employee: #{params[:id]}, user: #{current_user.email}, params: #{params.inspect}"

    begin
      @employee_detail = EmployeeDetail.find(params[:id])
      Rails.logger.info "Employee detail found: #{@employee_detail.id}"
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error "Employee detail not found: #{params[:id]}"
      if request.xhr?
        render json: { success: false, message: "❌ Employee detail not found. The record may have been deleted." }, status: :not_found
      else
        redirect_to employee_details_path, alert: "❌ Employee detail not found. The record may have been deleted."
      end
      return
    end

    # Check authorization - only L2 managers can edit L2 details when L3 has returned
    unless current_user.hod? || can_act_as_l2?(@employee_detail)
      if request.xhr?
        render json: { success: false, message: "❌ You are not authorized to edit L2 details" }, status: :forbidden
      else
        redirect_to show_l2_employee_detail_path(@employee_detail), alert: "❌ You are not authorized to edit L2 details"
      end
      return
    end

    # Validate required parameters
    unless params[:l2_percentage].present? && params[:l2_remarks].present?
      if request.xhr?
        render json: { success: false, message: "❌ L2 percentage and remarks are required" }, status: :unprocessable_entity
      else
        redirect_to show_l2_employee_detail_path(@employee_detail), alert: "❌ L2 percentage and remarks are required"
      end
      return
    end

    begin
      # Get the selected quarter
      selected_quarter = params[:selected_quarter]
      quarter_months = case selected_quarter
      when "Q1"
                        [ "april", "may", "june" ]
      when "Q2"
                        [ "july", "august", "september" ]
      when "Q3"
                        [ "october", "november", "december" ]
      when "Q4"
                        [ "january", "february", "march" ]
      else
                        []
      end

      # Get the department_id from params
      department_id = params[:department_id]

      # FIXED: Filter by department to only update achievements for the specific department
      # Find all achievements for the quarter that have L3 returned status
      updated_count = 0

      # Get all EmployeeDetail records for this employee (same employee name)
      all_employee_records = EmployeeDetail.where(employee_name: @employee_detail.employee_name)

      all_employee_records.each do |emp|
        emp.user_details.each do |user_detail|
          # FIXED: Only process user_details for the specific department
          next if department_id.present? && user_detail.department_id.to_s != department_id.to_s

          quarter_achievements = user_detail.achievements.select { |a| quarter_months.include?(a.month) }

          quarter_achievements.each do |achievement|
            # Update achievements that are in l3_returned or l2_returned status
            if achievement.status == "l3_returned" || achievement.status == "l2_returned"
              # Find or create achievement remark
              achievement_remark = achievement.achievement_remark || achievement.build_achievement_remark

              # Update L2 data
              achievement_remark.l2_percentage = params[:l2_percentage].to_f
              achievement_remark.l2_remarks = params[:l2_remarks]
              achievement_remark.save!

              # Update achievement status to l2_approved since L2 has edited and approved
              achievement.update!(status: "l2_approved")

              updated_count += 1
            end
          end
        end
      end

      Rails.logger.info "L2 Edit completed: #{updated_count} achievements updated"

      if request.xhr?
        render json: {
          success: true,
          count: updated_count,
          message: "✅ Successfully updated L2 details for #{updated_count} activities in #{selected_quarter} quarter",
          updated_status: "l2_approved"
        }
      else
        redirect_to show_l2_employee_detail_path(@employee_detail, quarter: selected_quarter),
                    notice: "✅ Successfully updated L2 details for #{updated_count} activities in #{selected_quarter} quarter"
      end

    rescue => e
      Rails.logger.error "Error in L2 Edit: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      if request.xhr?
        render json: { success: false, message: "❌ An error occurred while updating L2 details: #{e.message}" }, status: :internal_server_error
      else
        redirect_to show_l2_employee_detail_path(@employee_detail), alert: "❌ An error occurred while updating L2 details: #{e.message}"
      end
    end
  end

  def set_financial_year_context
    @selected_year = normalize_financial_year(params[:year])
    @selected_year_db = database_financial_year_value(UserDetail, @selected_year)
    @available_years = financial_year_options(UserDetail.distinct.pluck(:year))
  end

  def scoped_user_details_for_year(scope)
    return scope.where(year: @selected_year_db) if scope.klass.columns_hash["year"]&.type == :integer

    return scope.where(year: @selected_year) unless include_legacy_yearless_records?

    table_name = scope.klass.table_name
    scope.where("#{table_name}.year = ? OR #{table_name}.year IS NULL OR #{table_name}.year = ''", @selected_year)
  end

  def scoped_user_details_for_department_and_year(scope, department_id)
    scoped_user_details_for_year(scope.where(department_id: department_id))
  end

  def include_legacy_yearless_records?
    params[:year].blank? || @selected_year == current_financial_year_label
  end

  private

  def set_employee_detail
    @employee_detail = EmployeeDetail.find(params[:id])
  end

  def employee_detail_params
    params.require(:employee_detail).permit(
      :employee_name, :employee_email, :employee_code, :mobile_number,
      :l1_code, :l1_employer_name, :l2_code, :l2_employer_name,
      :l3_code, :l3_employer_name, :department
    )
  end

  def can_act_as_l1?(employee_detail)
    current_user.hod? ||
    current_user.employee_code == employee_detail.l1_code&.strip ||
    current_user.email == employee_detail.l1_employer_name
  end

  def can_act_as_l2?(employee_detail)
    current_user.hod? ||
    current_user.employee_code == employee_detail.l2_code&.strip ||
    current_user.email == employee_detail.l2_employer_name
  end

  def can_act_as_l3?(employee_detail)
    current_user.hod? ||
    current_user.employee_code == employee_detail.l3_code&.strip ||
    current_user.email == employee_detail.l3_employer_name
  end

  def get_quarter_months(quarter)
    case quarter
    when "Q1"
      [ "april", "may", "june" ]  # Q1 = Apr-May-Jun (Financial Year)
    when "Q2"
      [ "july", "august", "september" ]  # Q2 = Jul-Aug-Sep
    when "Q3"
      [ "october", "november", "december" ]  # Q3 = Oct-Nov-Dec
    when "Q4"
      [ "january", "february", "march" ]  # Q4 = Jan-Feb-Mar
    else
      []
    end
  end

  def get_all_quarters
    [ "Q1", "Q2", "Q3", "Q4" ]
  end

  # Group employees by quarters based on their activities (OPTIMIZED to prevent N+1 queries)
  def group_employees_by_quarters(employee_details)
    quarterly_data = {}

    get_all_quarters.each do |quarter|
      quarterly_data[quarter] = {
        employees: [],
        total_activities: 0,
        pending_activities: 0,
        approved_activities: 0,
        quarter_months: get_quarter_months(quarter)
      }
    end

    # Preload all necessary activity IDs to avoid N+1 queries
    activity_ids_by_department = {}

    employee_details.each do |employee|
      get_all_quarters.each do |quarter|
        quarter_months = get_quarter_months(quarter)

        # Use preloaded user_details instead of querying again
        quarter_activities = employee.user_details.select do |user_detail|
          user_detail.department.department_type == employee.department
        end

        if quarter_activities.any?
          employee_quarter_data = {
            employee: employee,
            activities: [],
            total_count: 0,
            pending_count: 0,
            approved_count: 0,
            overall_status: "pending"
          }

          quarter_activities.each do |user_detail|
            # Check each month in the quarter for targets
            quarter_months.each do |month|
              target_value = get_target_for_month(user_detail, month)
              next unless target_value.present? && target_value.to_s != "0"

              # Use preloaded achievements instead of find_by query
              achievement = user_detail.achievements.find { |ach| ach.month == month }

              activity_data = {
                user_detail: user_detail,
                achievement: achievement,
                month: month,
                activity_name: user_detail.activity&.activity_name,
                department: user_detail.department&.department_type,
                target: target_value,
                achievement_value: achievement&.achievement || "",
                status: achievement&.status || "pending",
                has_target: true
              }

              employee_quarter_data[:activities] << activity_data
              employee_quarter_data[:total_count] += 1

              case achievement&.status
              when "l1_approved", "l2_approved"
                employee_quarter_data[:approved_count] += 1
              else
                employee_quarter_data[:pending_count] += 1
              end
            end
          end

          # Determine overall status for this employee in this quarter
          if employee_quarter_data[:approved_count] == employee_quarter_data[:total_count] && employee_quarter_data[:total_count] > 0
            employee_quarter_data[:overall_status] = "approved"
          elsif employee_quarter_data[:pending_count] > 0
            employee_quarter_data[:overall_status] = "pending"
          end

          quarterly_data[quarter][:employees] << employee_quarter_data
          quarterly_data[quarter][:total_activities] += employee_quarter_data[:total_count]
          quarterly_data[quarter][:pending_activities] += employee_quarter_data[:pending_count]
          quarterly_data[quarter][:approved_activities] += employee_quarter_data[:approved_count]
        end
      end
    end

    quarterly_data
  end

  # Get quarterly activities for a specific quarter
  def get_quarterly_activities(user_details, quarter)
    # Use the new comprehensive method
    get_all_activities_for_quarter(user_details, quarter)
  end

  # Get all quarterly activities grouped by quarter - FIXED to show ALL activities
  def get_all_quarterly_activities(user_details)
    all_activities = {}

    get_all_quarters.each do |quarter|
      all_activities[quarter] = get_quarterly_activities(user_details, quarter)
    end

    all_activities
  end

  # NEW: Get all activities for a specific quarter (including those without achievements) - OPTIMIZED
  def get_all_activities_for_quarter(user_details, quarter)
    quarter_months = get_quarter_months(quarter)
    activities = []

    user_details.each do |user_detail|
      quarter_months.each do |month|
        # Check if there's a target for this month
        target_value = get_target_for_month(user_detail, month)
        next unless target_value.present? && target_value.to_s != "0"

        # Use preloaded achievements instead of find_by query
        achievement = user_detail.achievements.find { |ach| ach.month == month }

        # Create activity data regardless of whether achievement exists
        activity_data = {
          user_detail: user_detail,
          achievement: achievement,
          month: month,
          activity_name: user_detail.activity&.activity_name,
          department: user_detail.department&.department_type,
          target: target_value,
          achievement_value: achievement&.achievement || "",
          status: achievement&.status || "pending",
          employee_remarks: achievement&.employee_remarks || "",
          has_target: true,
          can_approve: can_approve_activity?(achievement),
          can_return: can_return_activity?(achievement)
        }

        activities << activity_data
      end
    end

    activities.sort_by { |a| [ a[:month], a[:activity_name] ] }
  end

  # Helper method to check if an activity can be approved
  def can_approve_activity?(achievement)
    return false unless achievement
    [ "pending", "l1_returned", "l2_returned" ].include?(achievement.status)
  end

  # Helper method to check if an activity can be returned
  def can_return_activity?(achievement)
    return false unless achievement
    [ "pending", "l1_approved", "l2_approved" ].include?(achievement.status)
  end

  # Helper method to get overall quarter status
  def get_quarter_overall_status(activities)
    return "no_data" if activities.empty?

    statuses = activities.map { |a| a[:status] }

    # FIXED: L2 statuses should take highest priority
    # If ANY activity has L2 approved, the quarter is L2 approved
    if statuses.include?("l2_approved")
      "l2_approved"
    # If ANY activity has L2 returned, the quarter is L2 returned
    elsif statuses.include?("l2_returned")
      "l2_returned"
    # If ALL activities are L1 approved, the quarter is L1 approved
    elsif statuses.all? { |s| [ "l1_approved" ].include?(s) }
      "l1_approved"
    # If ANY activity has L1 returned, the quarter is L1 returned
    elsif statuses.any? { |s| [ "l1_returned" ].include?(s) }
      "l1_returned"
    # If ANY activity has submitted status, the quarter is submitted
    elsif statuses.any? { |s| [ "submitted" ].include?(s) }
      "submitted"
    else
      "pending"
    end
  end

  # Get all activities that can be approved/returned for a specific quarter - OPTIMIZED
  def get_approvable_activities_for_quarter(user_details, quarter, approval_level = "l1")
    quarter_months = get_quarter_months(quarter)
    approvable_activities = []

    user_details.each do |user_detail|
      quarter_months.each do |month|
        # Check if there's a target for this month
        target_value = get_target_for_month(user_detail, month)
        next unless target_value.present? && target_value.to_s != "0"

        # Use preloaded achievements instead of find_by query
        achievement = user_detail.achievements.find { |ach| ach.month == month }

        # Check if this activity can be approved/returned at the specified level
        can_act = case approval_level
        when "l1"
          can_approve_activity?(achievement) || can_return_activity?(achievement)
        when "l2"
          achievement && [ "l1_approved", "l2_returned" ].include?(achievement.status)
        else
          false
        end

        next unless can_act

        approvable_activities << {
          user_detail: user_detail,
          achievement: achievement,
          month: month,
          activity_name: user_detail.activity&.activity_name,
          department: user_detail.department&.department_type,
          target: target_value,
          achievement_value: achievement&.achievement || "",
          status: achievement&.status || "pending",
          employee_remarks: achievement&.employee_remarks || "",
          can_approve: can_approve_activity?(achievement),
          can_return: can_return_activity?(achievement)
        }
      end
    end

    approvable_activities.sort_by { |a| [ a[:month], a[:activity_name] ] }
  end

  # Get target value for a specific month
  def get_target_for_month(user_detail, month)
    return nil unless user_detail.respond_to?(month.to_sym)
    user_detail.send(month.to_sym)
  end

  def process_quarterly_l1_approval
    # Add authorization check here for AJAX requests
    unless can_act_as_l1?(@employee_detail)
      return { success: false, message: "❌ You are not authorized to perform L1 actions on this record" }
    end

    # Validate and sanitize percentage parameter to prevent nil/-@ errors
    if params[:percentage].present?
      begin
        percentage_value = Float(params[:percentage])
        params[:percentage] = percentage_value.to_s
      rescue ArgumentError, TypeError => e
        Rails.logger.error "Invalid percentage value: #{params[:percentage]} - #{e.message}"
        params[:percentage] = "0.0"
      end
    else
      params[:percentage] = "0.0" # Set default if empty
    end

    approved_count = 0

    # Determine if this is an approval or return action
    action_type = params[:action_type] || "approve"
    is_approval = action_type.include?("approve")

    # Handle return level for return actions
    if !is_approval && params[:return_level].present?
      case params[:return_level]
      when "employee"
        new_status = "returned_to_employee"  # New status for employee return
      else
        new_status = "l1_returned"  # Default L1 return
      end
    else
      new_status = is_approval ? "l1_approved" : "l1_returned"
    end

    if params[:selected_quarter].present?
      # FIXED: Approve/Return specific quarter as a single unit
      quarter_months = get_quarter_months(params[:selected_quarter])
      Rails.logger.info "Processing L1 #{action_type} for quarter: #{params[:selected_quarter]}, months: #{quarter_months}"

      # FIXED: Department-wise processing - only process specific department if department_id is provided
      # IMPORTANT: Search across ALL EmployeeDetail records with the same employee_name (like show method does)
      user_details_to_process = if params[:department_id].present?
        Rails.logger.info "Processing department-wise for department_id: #{params[:department_id]}"

        # Get all EmployeeDetail records for this employee (same employee_name)
        all_employee_records = EmployeeDetail.where(employee_name: @employee_detail.employee_name)
        Rails.logger.info "Found #{all_employee_records.count} EmployeeDetail records for employee: #{@employee_detail.employee_name}"

        # Get all user_details from ALL employee records for this department
        user_details = []
        all_employee_records.each do |emp|
          emp.user_details.includes(:achievements, :activity, :department)
             .where(department_id: params[:department_id])
             .each do |ud|
            user_details << ud
          end
        end

        Rails.logger.info "Found #{user_details.count} user_details for department_id: #{params[:department_id]}"

        # If no user_details found, check what departments actually exist for this employee
        if user_details.empty?
          all_user_details = []
          all_employee_records.each do |emp|
            all_user_details.concat(emp.user_details.includes(:department).to_a)
          end
          all_department_ids = all_user_details.map(&:department_id).uniq.compact
          Rails.logger.warn "No user_details found for department_id: #{params[:department_id]}. Available department IDs: #{all_department_ids.join(', ')}"

          if all_department_ids.any?
            department_names = all_user_details.map { |ud| "#{ud.department&.department_type || 'Unknown'} (ID: #{ud.department_id})" }.uniq
            return {
              success: false,
              message: "❌ No activities found for department ID #{params[:department_id]}. Available departments: #{department_names.join(', ')}. Please select the correct department."
            }
          else
            return {
              success: false,
              message: "❌ No activities found for this employee. Please ensure activities are assigned to the employee first."
            }
          end
        end

        if user_details.any?
          Rails.logger.info "User detail IDs: #{user_details.map(&:id).join(', ')}"
        end
        user_details
      else
        Rails.logger.error "❌ Department ID is required for department-wise approval. Cannot approve all departments at once."
        return { success: false, message: "❌ Department ID is required for approval. Please select a specific department." }
      end

      user_details_to_process.each do |detail|
        begin
          Rails.logger.info "Processing user_detail: #{detail.id} for activity: #{detail.activity&.activity_name || 'N/A'}"
          Rails.logger.info "Total achievements for this user_detail: #{detail.achievements.count}"
          Rails.logger.info "Achievements by month: #{detail.achievements.map { |a| "#{a.month}:#{a.status}" }.join(', ')}"

          # FIXED: Process the entire quarter as one unit, not month by month
          quarter_achievements = []

          # First, collect all achievements for this quarter
          quarter_months.each do |month|
            # FIXED: Process ALL months in the quarter, not just those with targets
            # This ensures the entire quarter gets approved when L1 approves

            Rails.logger.info "Looking for achievement for month: #{month}"

            # Use preloaded achievements first, then find_or_create_by if needed
            begin
              achievement = detail.achievements.find { |ach| ach.month == month } ||
                           detail.achievements.find_or_create_by(month: month) do |new_achievement|
                             # Set default values for new achievements
                             new_achievement.status = "pending"
                             new_achievement.achievement = "0"
                           end

              Rails.logger.info "Found/created achievement: #{achievement.inspect}, status: #{achievement.status}"

              # Ensure achievement is saved and has an ID
              if achievement.new_record?
                achievement.save!
              end
            rescue => e
              Rails.logger.error "Error creating/finding achievement for month #{month}: #{e.message}"
              Rails.logger.error e.backtrace.join("\n")
              # Create a basic achievement manually if find_or_create_by fails
              achievement = detail.achievements.build(
                month: month,
                status: "pending",
                achievement: "0"
              )
              achievement.save!
            end

            # Add to quarter achievements list
            quarter_achievements << achievement
          end

          # FIXED: Now process the entire quarter as one unit
          if quarter_achievements.any?
            Rails.logger.info "Processing #{quarter_achievements.count} achievements for quarter #{params[:selected_quarter]}"
            Rails.logger.info "Achievements to process: #{quarter_achievements.map { |a| "#{a.month}:#{a.status}" }.join(', ')}"
            Rails.logger.info "Action type: #{action_type}, New status: #{new_status}"

            # FIXED: Update ALL achievements in the quarter to the same status
            quarter_achievements.each do |achievement|
              begin
                old_status = achievement.status
                achievement.update!(status: new_status)
                Rails.logger.info "Updated #{achievement.month} from #{old_status} to #{new_status}"

                # Create or update achievement remark with COMMON remarks for quarter
                remark = achievement.achievement_remark || achievement.build_achievement_remark
                remark.achievement = achievement # Ensure association is set
                remark.l1_remarks = params[:remarks] if params[:remarks].present?
                remark.l1_percentage = params[:percentage].to_f if params[:percentage].present?

                unless remark.save
                  Rails.logger.error "Failed to save achievement remark: #{remark.errors.full_messages.join(', ')}"
                  raise ActiveRecord::RecordInvalid.new(remark)
                end
                Rails.logger.info "Saved achievement remark for #{achievement.month}: l1_remarks=#{remark.l1_remarks.present? ? 'present' : 'nil'}, l1_percentage=#{remark.l1_percentage}"

                approved_count += 1
              rescue => e
                Rails.logger.error "Error updating achievement #{achievement.id} for month #{achievement.month}: #{e.message}"
                Rails.logger.error e.backtrace.join("\n")
                raise e # Re-raise to be caught by outer rescue
              end
            end

            Rails.logger.info "Successfully processed quarter #{params[:selected_quarter]} for activity #{detail.activity&.activity_name || 'N/A'}"
            Rails.logger.info "All #{quarter_achievements.count} months in quarter #{params[:selected_quarter]} now have status: #{new_status}"
          else
            Rails.logger.warn "No achievements found for quarter #{params[:selected_quarter]} in activity #{detail.activity&.activity_name || 'N/A'}"
          end
        rescue => e
          Rails.logger.error "Error processing user_detail #{detail.id}: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          # Continue processing other user_details even if one fails
          next
        end
      end
    else
      # Approve/Return all quarters
      # FIXED: Department-wise processing - only process specific department if department_id is provided
      user_details_to_process = if params[:department_id].present?
        Rails.logger.info "Processing all quarters department-wise for department_id: #{params[:department_id]}"
        @employee_detail.user_details.where(department_id: params[:department_id])
      else
        Rails.logger.error "❌ Department ID is required for department-wise approval. Cannot approve all departments at once."
        return { success: false, message: "❌ Department ID is required for approval. Please select a specific department." }
      end

      user_details_to_process.each do |detail|
        get_all_quarters.each do |quarter|
          quarter_months = get_quarter_months(quarter)

          # FIXED: Only process quarters that have existing achievements, don't create new ones
          existing_achievements = detail.achievements.select { |ach| quarter_months.include?(ach.month) }
          next if existing_achievements.empty?

          # Only process if ALL achievements in the quarter have the same status and can be processed
          existing_achievements.each do |achievement|
            # Update achievement status
            achievement.update!(status: new_status)

            remark = achievement.achievement_remark || achievement.build_achievement_remark
            remark.l1_remarks = params[:remarks] if params[:remarks].present?
            remark.l1_percentage = params[:percentage].to_f if params[:percentage].present?
            remark.save!

            approved_count += 1
          end
        end
      end
    end

    Rails.logger.info "Final approved_count: #{approved_count} for quarter #{params[:selected_quarter]}"

    if approved_count > 0
      # FIXED: Department-wise status update logic
      if params[:department_id].present?
        # For department-wise processing, check if all departments for this employee have the same status
        # If so, update the overall EmployeeDetail status
        all_departments = @employee_detail.user_details.includes(:achievements).group_by(&:department_id)
        all_departments_same_status = true

        all_departments.each do |dept_id, user_details|
          dept_achievements = user_details.flat_map(&:achievements)
          if params[:selected_quarter].present?
            quarter_months = get_quarter_months(params[:selected_quarter])
            dept_quarter_achievements = dept_achievements.select { |a| quarter_months.include?(a.month) }
          else
            dept_quarter_achievements = dept_achievements
          end

          dept_statuses = dept_quarter_achievements.map { |a| a.status || "pending" }
          dept_primary_status = if dept_statuses.any? { |s| s == "l3_approved" }
            "l3_approved"
          elsif dept_statuses.any? { |s| s == "l3_returned" }
            "l3_returned"
          elsif dept_statuses.any? { |s| s == "l2_approved" }
            "l2_approved"
          elsif dept_statuses.any? { |s| s == "l2_returned" }
            "l2_returned"
          elsif dept_statuses.any? { |s| s == "returned_to_employee" }
            "returned_to_employee"
          elsif dept_statuses.any? { |s| s == "l1_returned" }
            "l1_returned"
          elsif dept_statuses.any? { |s| s == "l1_approved" }
            "l1_approved"
          elsif dept_statuses.any? { |s| s == "submitted" }
            "submitted"
          else
            "pending"
          end

          if dept_primary_status != new_status
            all_departments_same_status = false
            break
          end
        end

        if all_departments_same_status
          @employee_detail.update!(status: new_status)
          Rails.logger.info "All departments have same status (#{new_status}), updated EmployeeDetail status"
        else
          Rails.logger.info "Departments have different statuses, not updating overall EmployeeDetail status"
        end
      else
        # For full employee processing, update EmployeeDetail status to match the new status
        @employee_detail.update!(status: new_status)
        Rails.logger.info "Updated EmployeeDetail status to: #{new_status}"
      end

      # Send email notifications after successful processing
      if params[:selected_quarter].present?
        # Get processed achievements for email notification
        quarter_months = get_quarter_months(params[:selected_quarter])
        processed_achievements = []

        # FIXED: Department-wise email notification
        user_details_for_email = if params[:department_id].present?
          @employee_detail.user_details.where(department_id: params[:department_id])
        else
          @employee_detail.user_details
        end

        user_details_for_email.each do |detail|
          quarter_months.each do |month|
            achievement = detail.achievements.find_by(month: month, status: new_status)
            processed_achievements << achievement if achievement
          end
        end
        send_approval_emails(new_status, @employee_detail, processed_achievements)
      else
        send_approval_emails(new_status, @employee_detail)
      end

      { success: true, count: approved_count }
    else
      action_text = is_approval ? "approve" : "return"
      { success: false, message: "❌ No activities found to #{action_text} for the selected quarter" }
    end
  end

# Process L1 quarterly return - FIXED
def process_quarterly_l1_return
  # This method now delegates to the approval method since it handles both approve and return
  process_quarterly_l1_approval
end

# Process L2 quarterly approval - FIXED
def process_quarterly_l2_approval
  # Add authorization check here for AJAX requests
  unless current_user.hod? || can_act_as_l2?(@employee_detail)
    return { success: false, message: "❌ You are not authorized to perform L2 actions on this record" }
  end

  # Validate and sanitize percentage parameters to prevent nil/-@ errors
  [ "percentage", "l2_percentage" ].each do |param_key|
    if params[param_key].present?
      begin
        percentage_value = Float(params[param_key])
        params[param_key] = percentage_value.to_s
      rescue ArgumentError, TypeError => e
        Rails.logger.error "Invalid #{param_key} value: #{params[param_key]} - #{e.message}"
        params[param_key] = "0.0"
      end
    end
  end

  approved_count = 0

  # Determine if this is an approval or return action
  action_type = params[:action_type] || "approve"
  is_approval = action_type.include?("approve")
  new_status = is_approval ? "l2_approved" : "l2_returned"

  Rails.logger.info "Processing L2 #{action_type} with status: #{new_status}"
  Rails.logger.info "Selected quarter: #{params[:selected_quarter]}"

  if params[:selected_quarter].present?
    # FIXED: Approve/Return specific quarter as a single unit
    quarter_months = get_quarter_months(params[:selected_quarter])
    Rails.logger.info "Processing L2 #{action_type} for quarter: #{params[:selected_quarter]}, months: #{quarter_months}"

    # FIXED: Department-wise processing - only process specific department if department_id is provided
    user_details_to_process = if params[:department_id].present?
      Rails.logger.info "Processing L2 department-wise for department_id: #{params[:department_id]}"

      # FIXED: Use the same logic as show_l2 action - get user_details from ALL EmployeeDetail records for this employee
      all_employee_records = EmployeeDetail.where(employee_name: @employee_detail.employee_name)
      user_details_to_process = []

      all_employee_records.each do |emp|
        emp.user_details.includes(:activity, :department, { achievements: :achievement_remark })
           .where(department_id: params[:department_id])
           .each do |ud|
          user_details_to_process << ud
        end
      end

      Rails.logger.info "Found #{user_details_to_process.count} user_details for department #{params[:department_id]}"
      user_details_to_process
    else
      Rails.logger.error "❌ Department ID is required for department-wise L2 approval. Cannot approve all departments at once."
      return { success: false, message: "❌ Department ID is required for L2 approval. Please select a specific department." }
    end

    user_details_to_process.each do |detail|
      Rails.logger.info "Processing user_detail: #{detail.id} for activity: #{detail.activity.activity_name}"
      Rails.logger.info "Total achievements for this user_detail: #{detail.achievements.count}"
      Rails.logger.info "Achievements by month: #{detail.achievements.map { |a| "#{a.month}:#{a.status}" }.join(', ')}"

      # FIXED: Process the entire quarter as one unit, not month by month
      quarter_achievements = []

      # First, collect all achievements for this quarter
      quarter_months.each do |month|
        # FIXED: Process ALL months in the quarter, not just those with targets
        # This ensures the entire quarter gets approved when L2 approves

        Rails.logger.info "Looking for achievement for month: #{month}"

        # Find or create achievement for this month
        achievement = detail.achievements.find_or_create_by(month: month) do |new_achievement|
          # Set default values for new achievements
          new_achievement.status = "pending"
        end
        Rails.logger.info "Found/created achievement: #{achievement.inspect}, status: #{achievement.status}"

        # Ensure achievement is saved and has an ID
        achievement.save! if achievement.new_record?

        # Add to quarter achievements list
        quarter_achievements << achievement
      end

      # FIXED: Now process the entire quarter as one unit
      if quarter_achievements.any?
        Rails.logger.info "Processing #{quarter_achievements.count} achievements for quarter #{params[:selected_quarter]}"
        Rails.logger.info "Achievements to process: #{quarter_achievements.map { |a| "#{a.month}:#{a.status}" }.join(', ')}"

        # Update ALL achievements in the quarter to the same status
        quarter_achievements.each do |achievement|
          # For L2 return, we should be able to return L1 approved achievements
          # For L2 approve, we need L1 approved, L2 returned, or L3 returned (when L3 returned to L2) achievements
          if is_approval
            # For approval, check eligibility - include l3_returned for L3_Return_L2 case
            eligible_statuses = [ "l1_approved", "l2_returned", "l3_returned" ]
            if eligible_statuses.include?(achievement.status)
              old_status = achievement.status
              achievement.update!(status: new_status)
              Rails.logger.info "Updated #{achievement.month} from #{old_status} to #{new_status}"

              # Create or update achievement remark with COMMON remarks for quarter
              remark = achievement.achievement_remark || achievement.build_achievement_remark
              remark.l2_remarks = params[:l2_remarks] || params[:remarks] if params[:l2_remarks].present? || params[:remarks].present?
              remark.l2_percentage = (params[:l2_percentage] || params[:percentage]).to_f if params[:l2_percentage].present? || params[:percentage].present?
              # IMPORTANT: Clear L3 data so L3 gets a fresh slate for the next review cycle
              # This happens when L2 acts after L3 returned the record back to L2
              remark.l3_remarks = nil
              remark.l3_percentage = nil
              remark.save!

              approved_count += 1
            else
              Rails.logger.info "Skipping #{achievement.month} - status #{achievement.status} not eligible for approval"
            end
          else
            # For return, process ALL achievements regardless of current status
            old_status = achievement.status
            # FIXED: Save return_to value to know whether it was returned to L1 or Employee
            achievement.update!(status: new_status, return_to: params[:return_to])
            Rails.logger.info "Updated #{achievement.month} from #{old_status} to #{new_status} (return to: #{params[:return_to]})"

            # Create or update achievement remark with COMMON remarks for quarter
            remark = achievement.achievement_remark || achievement.build_achievement_remark
            remark.l2_remarks = params[:l2_remarks] || params[:remarks] if params[:l2_remarks].present? || params[:remarks].present?
            remark.l2_percentage = (params[:l2_percentage] || params[:percentage]).to_f if params[:l2_percentage].present? || params[:percentage].present?
            # IMPORTANT: Clear L3 data so L3 gets a fresh slate for the next review cycle
            # This happens when L2 returns the record and L3 needs to review again
            remark.l3_remarks = nil
            remark.l3_percentage = nil
            remark.save!

            approved_count += 1
          end
        end

        Rails.logger.info "Successfully processed quarter #{params[:selected_quarter]} for activity #{detail.activity.activity_name}"
        Rails.logger.info "All eligible months in quarter #{params[:selected_quarter]} now have status: #{new_status}"
      else
        Rails.logger.warn "No achievements found for quarter #{params[:selected_quarter]} in activity #{detail.activity.activity_name}"
      end
    end
  else
    # Approve/Return all quarters
    # FIXED: Department-wise processing - only process specific department if department_id is provided
    user_details_to_process = if params[:department_id].present?
      Rails.logger.info "Processing L2 all quarters department-wise for department_id: #{params[:department_id]}"
      @employee_detail.user_details.where(department_id: params[:department_id])
    else
      Rails.logger.error "❌ Department ID is required for department-wise L2 approval. Cannot approve all departments at once."
      return { success: false, message: "❌ Department ID is required for L2 approval. Please select a specific department." }
    end

    user_details_to_process.each do |detail|
      get_all_quarters.each do |quarter|
        quarter_months = get_quarter_months(quarter)

        # FIXED: Only process quarters that have existing achievements, don't create new ones
        existing_achievements = detail.achievements.select { |ach| quarter_months.include?(ach.month) }
        next if existing_achievements.empty?

        # For L2 return, we should be able to return L1 approved achievements
        # For L2 approve, we need L1 approved or L2 returned achievements
        eligible_statuses = is_approval ? [ "l1_approved", "l2_returned" ] : [ "l1_approved" ]

        existing_achievements.each do |achievement|
          if eligible_statuses.include?(achievement.status)
            # Update achievement status
            if is_approval
              achievement.update!(status: new_status)
            else
              achievement.update!(status: new_status, return_to: params[:return_to])
            end

            remark = achievement.achievement_remark || achievement.build_achievement_remark
            remark.l2_remarks = params[:l2_remarks] || params[:remarks] if params[:l2_remarks].present? || params[:remarks].present?
            remark.l2_percentage = (params[:l2_percentage] || params[:percentage]).to_f if params[:l2_percentage].present? || params[:percentage].present?
            remark.save!

            approved_count += 1
          end
        end
      end
    end
  end

  Rails.logger.info "Final result: #{approved_count} achievements processed"
  if approved_count > 0
    # Update EmployeeDetail status to match the new status
    @employee_detail.update!(status: new_status)
    Rails.logger.info "Updated EmployeeDetail status to: #{new_status}"

    # Send email notifications after successful L2 processing
    if params[:selected_quarter].present?
      # Get processed achievements for email notification
      quarter_months = get_quarter_months(params[:selected_quarter])
      processed_achievements = []
      @employee_detail.user_details.each do |detail|
        quarter_months.each do |month|
          achievement = detail.achievements.find_by(month: month, status: new_status)
          processed_achievements << achievement if achievement
        end
      end

      # Handle L2 return with return_to parameter
      if !is_approval && params[:return_to].present?
        send_l2_return_emails(params[:return_to], @employee_detail, processed_achievements, params[:selected_quarter])
      else
        send_approval_emails(new_status, @employee_detail, processed_achievements)
      end
    else
      send_approval_emails(new_status, @employee_detail)
    end

    { success: true, count: approved_count }
  else
    action_text = is_approval ? "approve" : "return"
    { success: false, message: "❌ No L1 approved activities found to #{action_text} for the selected quarter" }
  end
end

# Process L2 quarterly return - FIXED
def process_quarterly_l2_return
  # This method now delegates to the approval method since it handles both approve and return
  process_quarterly_l2_approval
end

# Process L3 quarterly approval - NEW
def process_quarterly_l3_approval
  # Add authorization check here for AJAX requests
  unless current_user.hod? || can_act_as_l3?(@employee_detail)
    return { success: false, message: "❌ You are not authorized to perform L3 actions on this record" }
  end

  # Validate and sanitize percentage parameters to prevent nil/-@ errors
  [ "percentage", "l3_percentage" ].each do |param_key|
    if params[param_key].present?
      begin
        percentage_value = Float(params[param_key])
        params[param_key] = percentage_value.to_s
      rescue ArgumentError, TypeError => e
        Rails.logger.error "Invalid #{param_key} value: #{params[param_key]} - #{e.message}"
        params[param_key] = "0.0"
      end
    end
  end

  approved_count = 0

  # Determine if this is an approval or return action
  action_type = params[:action_type] || "approve"
  is_approval = action_type.include?("approve")

  # Handle return level for return actions
  if !is_approval && params[:return_level].present?
    case params[:return_level]
    when "employee"
      new_status = "returned_to_employee"
    when "l2"
      new_status = "l3_returned"  # L3 returned to L2 - show as L3 Returned
    when "l1"
      new_status = "l3_returned"  # L3 returned to L1 - show as L3 Returned
    else
      new_status = "l3_returned"  # Default fallback
    end
  else
    new_status = is_approval ? "l3_approved" : "l3_returned"
  end

  Rails.logger.info "Processing L3 #{action_type} with status: #{new_status}"
  Rails.logger.info "Selected quarter: #{params[:selected_quarter]}"

  if params[:selected_quarter].present?
    # Process specific quarter as a single unit
    quarter_months = get_quarter_months(params[:selected_quarter])
    Rails.logger.info "Processing L3 #{action_type} for quarter: #{params[:selected_quarter]}, months: #{quarter_months}"

    # Get the department_id from params
    department_id = params[:department_id]

    # FIXED: Filter by department to only process achievements for the specific department
    # Get all EmployeeDetail records for this employee (same employee name)
    all_employee_records = EmployeeDetail.where(employee_name: @employee_detail.employee_name)

    all_employee_records.each do |emp|
      emp.user_details.each do |detail|
        # FIXED: Only process user_details for the specific department
        next if department_id.present? && detail.department_id.to_s != department_id.to_s

        Rails.logger.info "Processing user_detail: #{detail.id} for activity: #{detail.activity.activity_name}"

        # Process the entire quarter as one unit
        quarter_achievements = []

        # First, collect all achievements for this quarter
        quarter_months.each do |month|
          Rails.logger.info "Looking for achievement for month: #{month}"

          # Find or create achievement for this month
          achievement = detail.achievements.find_or_create_by(month: month) do |new_achievement|
            # Set default values for new achievements
            new_achievement.status = "pending"
          end
          Rails.logger.info "Found/created achievement: #{achievement.inspect}, status: #{achievement.status}"

          # Ensure achievement is saved and has an ID
          achievement.save! if achievement.new_record?

          # Add to quarter achievements list
          quarter_achievements << achievement
        end

      # Now process the entire quarter as one unit
      if quarter_achievements.any?
        Rails.logger.info "Processing #{quarter_achievements.count} achievements for quarter #{params[:selected_quarter]}"

        # Update ALL achievements in the quarter to the same status
        quarter_achievements.each do |achievement|
          # For L3 return, we should be able to return L2 approved achievements
          # For L3 approve, we need L2 approved achievements only
          if is_approval
            # For approval, check eligibility (can work with any status except already L3 approved)
            if achievement.status != "l3_approved"
              old_status = achievement.status
              achievement.update!(status: new_status)
              Rails.logger.info "Updated #{achievement.month} from #{old_status} to #{new_status}"

              # Create or update achievement remark with COMMON remarks for quarter
              # FIXED: Preserve existing L1 and L2 data when L3 approves
              remark = achievement.achievement_remark || achievement.build_achievement_remark

              # Preserve existing L1 and L2 data if they exist
              existing_l1_percentage = remark.l1_percentage
              existing_l1_remarks = remark.l1_remarks
              existing_l2_percentage = remark.l2_percentage
              existing_l2_remarks = remark.l2_remarks

              # Set L3 data
              remark.l3_remarks = params[:l3_remarks] || params[:remarks] if params[:l3_remarks].present? || params[:remarks].present?
              remark.l3_percentage = (params[:l3_percentage] || params[:percentage]).to_f if params[:l3_percentage].present? || params[:percentage].present?

              # Restore L1 and L2 data if they were present
              remark.l1_percentage = existing_l1_percentage if existing_l1_percentage.present?
              remark.l1_remarks = existing_l1_remarks if existing_l1_remarks.present?
              remark.l2_percentage = existing_l2_percentage if existing_l2_percentage.present?
              remark.l2_remarks = existing_l2_remarks if existing_l2_remarks.present?

              remark.save!

              approved_count += 1
            else
              Rails.logger.info "Skipping #{achievement.month} - status #{achievement.status} not eligible for L3 approval"
            end
          else
            # For return, process ALL achievements regardless of current status
            old_status = achievement.status
            # Save return_level as return_to on achievement (critical for L2 routing to detect L3_Return_L2)
            achievement.update!(status: new_status, return_to: params[:return_level])
            Rails.logger.info "Updated #{achievement.month} from #{old_status} to #{new_status} (return to: #{params[:return_level]})"

            # Create or update achievement remark with COMMON remarks for quarter
            # FIXED: Preserve existing L1 and L2 data when L3 returns
            remark = achievement.achievement_remark || achievement.build_achievement_remark

            # Preserve existing L1 and L2 data if they exist
            existing_l1_percentage = remark.l1_percentage
            existing_l1_remarks = remark.l1_remarks
            existing_l2_percentage = remark.l2_percentage
            existing_l2_remarks = remark.l2_remarks

            # Set L3 data (saved so L2 can see why it was returned)
            remark.l3_remarks = params[:l3_remarks] || params[:remarks] if params[:l3_remarks].present? || params[:remarks].present?
            remark.l3_percentage = (params[:l3_percentage] || params[:percentage]).to_f if params[:l3_percentage].present? || params[:percentage].present?

            # Restore L1 and L2 data if they were present
            remark.l1_percentage = existing_l1_percentage if existing_l1_percentage.present?
            remark.l1_remarks = existing_l1_remarks if existing_l1_remarks.present?
            remark.l2_percentage = existing_l2_percentage if existing_l2_percentage.present?
            remark.l2_remarks = existing_l2_remarks if existing_l2_remarks.present?

            remark.save!

            approved_count += 1
          end
        end

        Rails.logger.info "Successfully processed quarter #{params[:selected_quarter]} for activity #{detail.activity.activity_name}"
      else
        Rails.logger.warn "No achievements found for quarter #{params[:selected_quarter]} in activity #{detail.activity.activity_name}"
      end
      end
    end
  else
    # Process all quarters
    @employee_detail.user_details.each do |detail|
      get_all_quarters.each do |quarter|
        quarter_months = get_quarter_months(quarter)

        # FIXED: Only process quarters that have existing achievements, don't create new ones
        existing_achievements = detail.achievements.select { |ach| quarter_months.include?(ach.month) }
        next if existing_achievements.empty?

        existing_achievements.each do |achievement|
          # For L3 return, we should be able to return L2 approved achievements
          # For L3 approve, we need L2 approved achievements only
          if achievement.status == "l2_approved"
            # Update achievement status
            achievement.update!(status: new_status)

            remark = achievement.achievement_remark || achievement.build_achievement_remark
            remark.l3_remarks = params[:l3_remarks] || params[:remarks] if params[:l3_remarks].present? || params[:remarks].present?
            remark.l3_percentage = (params[:l3_percentage] || params[:percentage]).to_f if params[:l3_percentage].present? || params[:percentage].present?
            remark.save!

            approved_count += 1
          end
        end
      end
    end
  end

  Rails.logger.info "Final result: #{approved_count} achievements processed"
  if approved_count > 0
    # Update EmployeeDetail status to match the new status
    @employee_detail.update!(status: new_status)
    Rails.logger.info "Updated EmployeeDetail status to: #{new_status}"

    # Send email notifications after successful L3 processing
    if params[:selected_quarter].present?
      # Get processed achievements for email notification
      quarter_months = get_quarter_months(params[:selected_quarter])
      processed_achievements = []
      @employee_detail.user_details.each do |detail|
        quarter_months.each do |month|
          achievement = detail.achievements.find_by(month: month, status: new_status)
          processed_achievements << achievement if achievement
        end
      end
      # Handle L3 return with return_level parameter
      if !is_approval && params[:return_level].present?
        send_l3_return_emails(params[:return_level], @employee_detail, processed_achievements, params[:selected_quarter])
      else
        send_approval_emails(new_status, @employee_detail, processed_achievements)
      end
    else
      send_approval_emails(new_status, @employee_detail)
    end

    { success: true, count: approved_count }
  else
    action_text = is_approval ? "approve" : "return"
    { success: false, message: "❌ No eligible activities found to #{action_text} for the selected quarter" }
  end
end

# Process L3 quarterly return - FIXED
def process_quarterly_l3_return
  # This method now delegates to the approval method since it handles both approve and return
  process_quarterly_l3_approval
end

private

# Email notification helper methods
def send_approval_emails(action_type, employee_detail, achievements = nil)
  case action_type
  when "l1_approved"
    send_l1_approval_emails(employee_detail, achievements)  # Send to employee
    send_l2_approval_emails(employee_detail, achievements)  # Send to L2 manager
  when "l2_approved"
    send_l2_approval_emails_to_employee(employee_detail, achievements)  # Send to employee
    send_l3_approval_emails(employee_detail, achievements)  # Send to L3 manager
  when "l3_approved"
    send_final_approval_emails(employee_detail, achievements)
  when "l1_returned", "l2_returned", "l3_returned"
    send_return_emails(action_type, employee_detail, achievements)
  when "returned_to_employee"
    send_employee_return_emails(employee_detail, achievements)
  end
end

def send_l1_approval_emails(employee_detail, achievements)
  if employee_detail.employee_email.present?
    begin
      if achievements&.any?
        # Send quarterly email to employee
        quarter = params[:selected_quarter] || determine_quarter_from_achievements(achievements)
        ApprovalMailer.quarterly_l1_approved(employee_detail, quarter, achievements).deliver_now

        # Send SMS to employee for L1 approval
        send_sms_to_employee(employee_detail, quarter, "l1_approved")
      else
        # Send individual emails for each achievement to employee
        employee_detail.user_details.each do |user_detail|
          user_detail.achievements.where(status: "l1_approved").each do |achievement|
            ApprovalMailer.l1_approved(achievement).deliver_now
          end
        end

        # Send SMS to employee for individual L1 approval
        quarter = determine_quarter_from_achievements(achievements) || "achievements"
        send_sms_to_employee(employee_detail, quarter, "l1_approved")
      end
    rescue => e
      Rails.logger.error "Failed to send L1 approval emails to employee: #{e.message}"
    end
  end
end

def send_l2_approval_emails(employee_detail, achievements)
  l2_user = User.find_by(employee_code: employee_detail.l2_code)

  if l2_user&.email.present?
    begin
      if achievements&.any?
        # Send quarterly email
        quarter = params[:selected_quarter] || determine_quarter_from_achievements(achievements)
        ApprovalMailer.quarterly_l2_approval_request(employee_detail, quarter, achievements).deliver_now
      else
        # Send individual emails for each achievement
        employee_detail.user_details.each do |user_detail|
          user_detail.achievements.where(status: "l1_approved").each do |achievement|
            ApprovalMailer.l2_approval_request(achievement, l2_user.email).deliver_now
          end
        end
      end
    rescue => e
      Rails.logger.error "Failed to send L2 approval emails: #{e.message}"
    end
  else
  end
end

def send_l2_approval_emails_to_employee(employee_detail, achievements)
  if employee_detail.employee_email.present?
    begin
      if achievements&.any?
        # Send quarterly email to employee
        quarter = params[:selected_quarter] || determine_quarter_from_achievements(achievements)
        ApprovalMailer.quarterly_l2_approved(employee_detail, quarter, achievements).deliver_now

        # Send SMS to employee and L1 for L2 approval
        send_sms_to_employee(employee_detail, quarter, "l2_approved")
        send_sms_to_l1_for_l2_action(employee_detail, quarter, "approved")
      else
        # Send individual emails for each achievement to employee
        employee_detail.user_details.each do |user_detail|
          user_detail.achievements.where(status: "l2_approved").each do |achievement|
            ApprovalMailer.l2_approved(achievement).deliver_now
          end
        end

        # Send SMS to employee and L1 for individual L2 approval
        quarter = determine_quarter_from_achievements(achievements) || "achievements"
        send_sms_to_employee(employee_detail, quarter, "l2_approved")
        send_sms_to_l1_for_l2_action(employee_detail, quarter, "approved")
      end
    rescue => e
      Rails.logger.error "Failed to send L2 approval emails to employee: #{e.message}"
    end
  end
end

def send_l3_approval_emails(employee_detail, achievements)
  l3_user = User.find_by(employee_code: employee_detail.l3_code)

  if l3_user&.email.present?
    begin
      if achievements&.any?
        # Send quarterly email
        quarter = params[:selected_quarter] || determine_quarter_from_achievements(achievements)
        ApprovalMailer.quarterly_l3_approval_request(employee_detail, quarter, achievements).deliver_now
      else
        # Send individual emails for each achievement
        employee_detail.user_details.each do |user_detail|
          user_detail.achievements.where(status: "l2_approved").each do |achievement|
            ApprovalMailer.l3_approval_request(achievement, l3_user.email).deliver_now
          end
        end
      end
    rescue => e
      Rails.logger.error "Failed to send L3 approval emails: #{e.message}"
    end
  else
  end
end

def send_final_approval_emails(employee_detail, achievements)
  if employee_detail.employee_email.present?
    begin
      if achievements&.any?
        # Send quarterly L3 approved email to employee
        quarter = params[:selected_quarter] || determine_quarter_from_achievements(achievements)
        ApprovalMailer.quarterly_l3_approved(employee_detail, quarter, achievements).deliver_now

        # Send SMS to employee, L1, and L2 for L3 approval
        send_sms_to_employee(employee_detail, quarter, "l3_approved")
        send_sms_to_l1_for_l3_action(employee_detail, quarter, "approved")
        send_sms_to_l2_for_l3_action(employee_detail, quarter, "approved")
      else
        # Send individual emails for each achievement to employee
        employee_detail.user_details.each do |user_detail|
          user_detail.achievements.where(status: "l3_approved").each do |achievement|
            ApprovalMailer.l3_approved(achievement).deliver_now
          end
        end

        # Send SMS to employee, L1, and L2 for individual L3 approval
        quarter = determine_quarter_from_achievements(achievements) || "achievements"
        send_sms_to_employee(employee_detail, quarter, "l3_approved")
        send_sms_to_l1_for_l3_action(employee_detail, quarter, "approved")
        send_sms_to_l2_for_l3_action(employee_detail, quarter, "approved")
      end
    rescue => e
      Rails.logger.error "Failed to send final approval emails: #{e.message}"
    end
  else
  end
end

def send_return_emails(action_type, employee_detail, achievements)
  return_level = case action_type
  when "l1_returned"
                  "L1"
  when "l2_returned"
                  "L2"
  when "l3_returned"
                  "L3"
  end

  if employee_detail.employee_email.present?
    begin
      if achievements&.any?
        # Check if this is a quarterly return (has selected_quarter or multiple achievements from same quarter)
        quarter = params[:selected_quarter] || determine_quarter_from_achievements(achievements)

        # For quarterly returns, send quarterly email (similar to L2)
        # If selected_quarter is present, it's definitely a quarterly return
        # Otherwise, check if we have multiple achievements (likely a quarter)
        if params[:selected_quarter].present? || (quarter.present? && achievements.length > 1)
          case action_type
          when "l1_returned"
            # Send quarterly L1 return email to user
            ApprovalMailer.quarterly_l1_returned(employee_detail, quarter, achievements).deliver_now
            Rails.logger.info "Sent L1 quarterly return email to employee: #{employee_detail.employee_email}"
          when "l2_returned"
            # Send quarterly L2 return email to user
            ApprovalMailer.quarterly_l2_returned(employee_detail, quarter, achievements).deliver_now
            Rails.logger.info "Sent L2 quarterly return email to employee: #{employee_detail.employee_email}"
          when "l3_returned"
            # Send quarterly L3 return email to user
            ApprovalMailer.quarterly_l3_returned(employee_detail, quarter, achievements).deliver_now
            Rails.logger.info "Sent L3 quarterly return email to employee: #{employee_detail.employee_email}"
          end
        else
          # Send for each achievement that was returned (individual returns)
          achievements.each do |achievement|
            ApprovalMailer.achievement_returned(achievement, employee_detail.employee_email).deliver_now
          end
        end

        # Send SMS based on return level
        quarter ||= determine_quarter_from_achievements(achievements)
        case action_type
        when "l1_returned"
          send_sms_to_employee(employee_detail, quarter, "l1_returned")
        when "l2_returned"
          send_sms_to_employee(employee_detail, quarter, "l2_returned")
          send_sms_to_l1_for_l2_action(employee_detail, quarter, "returned")
        when "l3_returned"
          send_sms_to_employee(employee_detail, quarter, "l3_returned")
          send_sms_to_l1_for_l3_action(employee_detail, quarter, "returned")
          send_sms_to_l2_for_l3_action(employee_detail, quarter, "returned")
        end
      else
        # Send for all returned achievements
        status_to_find = action_type
        employee_detail.user_details.each do |user_detail|
          user_detail.achievements.where(status: status_to_find).each do |achievement|
            ApprovalMailer.achievement_returned(achievement, employee_detail.employee_email).deliver_now
          end
        end

        # Send SMS for individual returns
        quarter = determine_quarter_from_achievements(achievements) || "achievements"
        case action_type
        when "l1_returned"
          send_sms_to_employee(employee_detail, quarter, "l1_returned")
        when "l2_returned"
          send_sms_to_employee(employee_detail, quarter, "l2_returned")
          send_sms_to_l1_for_l2_action(employee_detail, quarter, "returned")
        when "l3_returned"
          send_sms_to_employee(employee_detail, quarter, "l3_returned")
          send_sms_to_l1_for_l3_action(employee_detail, quarter, "returned")
          send_sms_to_l2_for_l3_action(employee_detail, quarter, "returned")
        end
      end
    rescue => e
      Rails.logger.error "Failed to send return emails: #{e.message}"
    end
  else
  end
end

def determine_quarter_from_achievements(achievements)
  return nil if achievements.blank?

  # Get the first achievement's month to determine quarter
  first_month = achievements.first.month

  case first_month
  when "april", "may", "june"
    "Q1"
  when "july", "august", "september"
    "Q2"
  when "october", "november", "december"
    "Q3"
  when "january", "february", "march"
    "Q4"
  else
    nil
  end
end

# SMS helper methods
def send_sms_to_employee(employee_detail, quarter, action_type)
  return unless employee_detail.mobile_number.present?

  begin
    message = case action_type
    when "l1_approved"
      SmsService.l1_approval_message(employee_detail.employee_name, quarter)
    when "l1_returned"
      SmsService.l1_return_message(employee_detail.employee_name, quarter)
    when "l2_approved"
      SmsService.l2_approval_message(employee_detail.employee_name, quarter)
    when "l2_returned"
      SmsService.l2_return_message(employee_detail.employee_name, quarter)
    when "l3_approved"
      SmsService.l3_approval_message(employee_detail.employee_name, quarter)
    when "l3_returned"
      SmsService.l3_return_message(employee_detail.employee_name, quarter)
    end

    result = SmsService.send_sms(employee_detail.mobile_number, message)
    if result[:success]
      Rails.logger.info "SMS sent to employee #{employee_detail.employee_name} (#{employee_detail.mobile_number}) for #{action_type}"
    else
      Rails.logger.error "Failed to send SMS to employee: #{result[:message]}"
    end
  rescue => e
    Rails.logger.error "SMS to employee failed: #{e.message}"
  end
end

def send_sms_to_l1_for_l2_action(employee_detail, quarter, action)
  return unless employee_detail.l1_code.present?

  begin
    l1_manager = EmployeeDetail.find_by("employee_code LIKE ?", employee_detail.l1_code.strip + "%")
    return unless l1_manager&.mobile_number.present?

    message = SmsService.l1_notification_message(employee_detail.employee_name, quarter, action)
    result = SmsService.send_sms(l1_manager.mobile_number, message)
    if result[:success]
      Rails.logger.info "SMS sent to L1 manager #{l1_manager.employee_name} for L2 #{action}"
    else
      Rails.logger.error "Failed to send SMS to L1 manager: #{result[:message]}"
    end
  rescue => e
    Rails.logger.error "SMS to L1 manager failed: #{e.message}"
  end
end

def send_sms_to_l1_for_l3_action(employee_detail, quarter, action)
  return unless employee_detail.l1_code.present?

  begin
    l1_manager = EmployeeDetail.find_by("employee_code LIKE ?", employee_detail.l1_code.strip + "%")
    return unless l1_manager&.mobile_number.present?

    message = SmsService.l1_notification_message(employee_detail.employee_name, quarter, action)
    result = SmsService.send_sms(l1_manager.mobile_number, message)
    if result[:success]
      Rails.logger.info "SMS sent to L1 manager #{l1_manager.employee_name} for L3 #{action}"
    else
      Rails.logger.error "Failed to send SMS to L1 manager: #{result[:message]}"
    end
  rescue => e
    Rails.logger.error "SMS to L1 manager failed: #{e.message}"
  end
end

def send_sms_to_l2_for_l3_action(employee_detail, quarter, action)
  return unless employee_detail.l2_code.present?

  begin
    l2_manager = EmployeeDetail.find_by("employee_code LIKE ?", employee_detail.l2_code.strip + "%")
    return unless l2_manager&.mobile_number.present?

    message = SmsService.l2_notification_message_for_l3(employee_detail.employee_name, quarter, action)
    result = SmsService.send_sms(l2_manager.mobile_number, message)
    if result[:success]
      Rails.logger.info "SMS sent to L2 manager #{l2_manager.employee_name} for L3 #{action}"
    else
      Rails.logger.error "Failed to send SMS to L2 manager: #{result[:message]}"
    end
  rescue => e
    Rails.logger.error "SMS to L2 manager failed: #{e.message}"
  end
end

def send_employee_return_emails(employee_detail, achievements)
  if employee_detail.employee_email.present?
    begin
      if achievements&.any?
        # Group achievements by quarter and send one email per quarter
        quarter_achievements = group_achievements_by_quarter(achievements)

        quarter_achievements.each do |quarter, quarter_achievements_list|
          # Send one email per quarter
          ApprovalMailer.quarterly_achievement_returned_to_employee(employee_detail, quarter, quarter_achievements_list).deliver_now
        end
      else
        # Send for all achievements returned to employee, grouped by quarter
        all_returned_achievements = []
        employee_detail.user_details.each do |user_detail|
          user_detail.achievements.where(status: "returned_to_employee").each do |achievement|
            all_returned_achievements << achievement
          end
        end

        if all_returned_achievements.any?
          quarter_achievements = group_achievements_by_quarter(all_returned_achievements)

          quarter_achievements.each do |quarter, quarter_achievements_list|
            # Send one email per quarter
            ApprovalMailer.quarterly_achievement_returned_to_employee(employee_detail, quarter, quarter_achievements_list).deliver_now
          end
        end
      end
    rescue => e
      Rails.logger.error "Failed to send employee return emails: #{e.message}"
    end
  else
    Rails.logger.warn "No employee email found for #{employee_detail.employee_name} (#{employee_detail.employee_code})"
  end
end

# Helper method to group achievements by quarter
def group_achievements_by_quarter(achievements)
  quarter_groups = {}

  achievements.each do |achievement|
    quarter = determine_quarter_from_month(achievement.month)
    quarter_groups[quarter] ||= []
    quarter_groups[quarter] << achievement
  end

  quarter_groups
end

# Helper method to determine quarter from month
def determine_quarter_from_month(month)
  case month.downcase
  when "january", "february", "march"
    "Q1"
  when "april", "may", "june"
    "Q2"
  when "july", "august", "september"
    "Q3"
  when "october", "november", "december"
    "Q4"
  when "q1"
    "Q1"
  when "q2"
    "Q2"
  when "q3"
    "Q3"
  when "q4"
    "Q4"
  else
    "Unknown"
  end
end

def determine_quarter_from_achievements(achievements)
  return "Unknown" unless achievements&.any?

  first_month = achievements.first.month
  case first_month
  when "april", "may", "june"
    "Q1"
  when "july", "august", "september"
    "Q2"
  when "october", "november", "december"
    "Q3"
  when "january", "february", "march"
    "Q4"
  else
    "Unknown"
  end
end

def send_employee_creation_sms(employee_detail)
  begin
    # Only send SMS if employee has both L1 and L2 codes (indicating proper hierarchy)
    l1_code = employee_detail.l1_code
    l2_code = employee_detail.l2_code
    return unless l1_code.present? && l2_code.present?

    # Find L1 manager's mobile number
    l1_manager = EmployeeDetail.find_by("employee_code LIKE ?", l1_code.strip + "%")
    return unless l1_manager&.mobile_number.present?

    l1_mobile = l1_manager.mobile_number.to_s.strip.gsub(/\D/, "")
    return if l1_mobile.length < 10

    # Prepare SMS message for new employee creation
    message = "New Employee Created: Code: #{employee_detail.employee_code}, Name: #{employee_detail.employee_name}, Department: #{employee_detail.department}. Please assign KRA activities. Ploughman Agro Private Limited"

    # Send SMS using the same API
    require "httparty"

    params = {
      authkey: "37317061706c39353312",
      mobiles: l1_mobile,
      message: message,
      sender: "PLOAPL",
      route: "2",
      country: "0",
      DLT_TE_ID: "1707175594432371766",
      unicode: "1"
    }

    api_url = "https://sms.yoursmsbox.com/api/sendhttp.php"
    response = HTTParty.get(api_url, query: params)

    Rails.logger.info "Employee creation SMS sent to L1 #{l1_manager.employee_name} (#{l1_mobile}): #{response.success? ? 'Success' : 'Failed'}"

  rescue => e
    Rails.logger.error "Failed to send employee creation SMS: #{e.message}"
  end
end

# Send L2 return emails based on return_to parameter
def send_l2_return_emails(return_to, employee_detail, achievements, quarter)
  begin
    case return_to
    when "employee"
      # Send email to employee for refilling
      ApprovalMailer.l2_quarterly_returned_to_employee(employee_detail, quarter, achievements).deliver_now
      Rails.logger.info "Sent L2 return email to employee: #{employee_detail.employee_email}"

    when "l1"
      # Send email to L1 for review
      ApprovalMailer.l2_quarterly_returned_to_l1(employee_detail, quarter, achievements).deliver_now
      Rails.logger.info "Sent L2 return email to L1 for employee: #{employee_detail.employee_name}"

    else
      Rails.logger.error "Invalid return_to parameter: #{return_to}"
    end
  rescue => e
    Rails.logger.error "Failed to send L2 return emails: #{e.message}"
  end
end

# Send L3 return emails based on return_level parameter
def send_l3_return_emails(return_level, employee_detail, achievements, quarter)
  begin
    case return_level
    when "employee"
      # Send email to employee for refilling
      ApprovalMailer.l3_quarterly_returned_to_employee(employee_detail, quarter, achievements).deliver_now
      Rails.logger.info "Sent L3 return email to employee: #{employee_detail.employee_email}"

    when "l1"
      # Send email to L1 for review
      ApprovalMailer.l3_quarterly_returned_to_l1(employee_detail, quarter, achievements).deliver_now
      Rails.logger.info "Sent L3 return email to L1 for employee: #{employee_detail.employee_name}"

    when "l2"
      # Send email to L2 for review
      ApprovalMailer.l3_quarterly_returned_to_l2(employee_detail, quarter, achievements).deliver_now
      Rails.logger.info "Sent L3 return email to L2 for employee: #{employee_detail.employee_name}"

    else
      Rails.logger.error "Invalid return_level parameter: #{return_level}"
    end
  rescue => e
    Rails.logger.error "Failed to send L3 return emails: #{e.message}"
  end
end
end
