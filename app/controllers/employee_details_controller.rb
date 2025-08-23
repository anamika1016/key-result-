require 'roo'
require 'axlsx'

class EmployeeDetailsController < ApplicationController
  before_action :set_employee_detail, only: [:edit, :update, :destroy]
  load_and_authorize_resource except: [:approve, :return, :l2_approve, :l2_return]
  
  def index
    @employee_detail = EmployeeDetail.new
    @q = EmployeeDetail.ransack(params[:q])
    @employee_details = @q.result.order(created_at: :desc).page(params[:page]).per(10)
  end

  def create
    @employee_detail = EmployeeDetail.new(employee_detail_params)
    @employee_detail.user = current_user

    @q = EmployeeDetail.ransack(params[:q])
    if @employee_detail.save
      redirect_to employee_details_path, notice: 'Employee created successfully.'
    else
      @employee_details = @q.result.order(created_at: :desc).page(params[:page]).per(10)
      flash.now[:alert] = 'Failed to create employee.'
      render :index, status: :unprocessable_entity
    end
  end

  def update
    if @employee_detail.update(employee_detail_params)
      redirect_to employee_details_path, notice: 'Employee updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @employee_detail.destroy
    redirect_to employee_details_path, notice: 'Employee deleted successfully.'
  end

  def export_xlsx
    @employee_details = EmployeeDetail.all

    package = Axlsx::Package.new
    workbook = package.workbook

    workbook.add_worksheet(name: "Employees") do |sheet|
      sheet.add_row [
        "Employee ID", "Name", "Email", "Employee Code",
        "L1 Code", "L2 Code", "L1 Name", "L2 Name", "Post", "Department"
      ]

      @employee_details.each do |emp|
        sheet.add_row [
          emp.employee_id,
          emp.employee_name,
          emp.employee_email,
          emp.employee_code,
          emp.l1_code,
          emp.l2_code,
          emp.l1_employer_name,
          emp.l2_employer_name,
          emp.post,
          emp.department
        ]
      end
    end

    tempfile = Tempfile.new(["employee_details", ".xlsx"])
    package.serialize(tempfile.path)
    send_file tempfile.path, filename: "employee_details.xlsx", type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  def import
    file = params[:file]

    if file.nil?
      redirect_to employee_details_path, alert: 'Please upload a file.'
      return
    end

    spreadsheet = Roo::Spreadsheet.open(file.path)
    header = spreadsheet.row(1)

    header_map = {
      "Employee ID" => "employee_id",
      "Name" => "employee_name",
      "Email" => "employee_email",
      "Employee Code" => "employee_code",
      "L1 Code" => "l1_code",
      "L2 Code" => "l2_code",
      "L1 Name" => "l1_employer_name",
      "L2 Name" => "l2_employer_name",
      "Post" => "post",
      "Department" => "department"
    }

    (2..spreadsheet.last_row).each do |i|
      row = Hash[[header, spreadsheet.row(i)].transpose]
      mapped_row = row.transform_keys { |key| header_map[key] }.compact

      begin
        EmployeeDetail.create!(mapped_row)
      rescue => e
        puts "Import failed for row #{i}: #{e.message}"
        next
      end
    end

    redirect_to employee_details_path, notice: "✅ Employees imported successfully!"
  end

  # L1 Dashboard - Show quarterly data
  def l1
    authorize! :l1, EmployeeDetail

    if current_user.hod?
      @employee_details = EmployeeDetail.includes(user_details: [:activity, :department, :achievements]).all
    else
      @employee_details = EmployeeDetail
                            .where(status: ['pending', 'l1_returned', 'l1_approved', 'l2_returned', 'l2_approved'])
                            .where(l1_code: current_user.employee_code)
                            .includes(user_details: [:activity, :department, :achievements])
    end

    # Group employees by quarters for display
    @quarterly_data = group_employees_by_quarters(@employee_details)
  end

  # Show employee details with quarterly view
  def show    
    @employee_detail = EmployeeDetail.find(params[:id])
    authorize! :read, @employee_detail
    
    @user_detail_id = params[:user_detail_id]
    @selected_quarter = params[:quarter]
    
    # Get all user details with achievements
    @user_details = @employee_detail.user_details
                      .includes(:activity, :department, :achievements)
                      .joins(:achievements)
                      .where.not(achievements: { achievement: [nil, ''] })
                      .distinct

    # If quarter is selected, filter achievements by quarter
    if @selected_quarter.present?
      @quarterly_activities = get_quarterly_activities(@user_details, @selected_quarter)
    else
      @quarterly_activities = get_all_quarterly_activities(@user_details)
    end

    @can_approve_or_return = can_act_as_l1?(@employee_detail)
  end

  # Quarterly approval - approve all activities for a quarter
  def approve
    @employee_detail = EmployeeDetail.find(params[:id])

    if can_act_as_l1?(@employee_detail)
      Rails.logger.debug "PROCESSING L1 QUARTERLY APPROVAL"
      result = process_quarterly_l1_approval
      
      if result[:success]
        redirect_to employee_detail_path(@employee_detail, quarter: params[:selected_quarter]), 
                    notice: "✅ Successfully approved #{result[:count]} activities for #{params[:selected_quarter] || 'all quarters'} by L1"
      else
        redirect_back fallback_location: root_path, alert: result[:message]
      end
    
    elsif can_act_as_l2?(@employee_detail)
      Rails.logger.debug "PROCESSING L2 QUARTERLY APPROVAL"
      result = process_quarterly_l2_approval
      
      if result[:success]
        redirect_to employee_detail_path(@employee_detail, quarter: params[:selected_quarter]), 
                    notice: "✅ Successfully approved #{result[:count]} activities for #{params[:selected_quarter] || 'all quarters'} by L2"
      else
        redirect_back fallback_location: root_path, alert: result[:message]
      end
    else
      Rails.logger.debug "AUTHORIZATION FAILED"
      redirect_back fallback_location: root_path, alert: "❌ You are not authorized to approve this record"
    end
  end

  # Quarterly return - return all activities for a quarter
  def return
    @employee_detail = EmployeeDetail.find(params[:id])
    
    if can_act_as_l1?(@employee_detail)
      Rails.logger.debug "PROCESSING L1 QUARTERLY RETURN"
      result = process_quarterly_l1_return
      
      if result[:success]
        redirect_to employee_detail_path(@employee_detail, quarter: params[:selected_quarter]), 
                    alert: "⚠️ Successfully returned #{result[:count]} activities for #{params[:selected_quarter] || 'all quarters'} by L1"
      else
        redirect_back fallback_location: root_path, alert: result[:message]
      end

    elsif can_act_as_l2?(@employee_detail)
      Rails.logger.debug "PROCESSING L2 QUARTERLY RETURN"
      result = process_quarterly_l2_return
      
      if result[:success]
        redirect_to employee_detail_path(@employee_detail, quarter: params[:selected_quarter]), 
                    alert: "⚠️ Successfully returned #{result[:count]} activities for #{params[:selected_quarter] || 'all quarters'} by L2"
      else
        redirect_back fallback_location: root_path, alert: result[:message]
      end
    else
      Rails.logger.debug "AUTHORIZATION FAILED"
      redirect_back fallback_location: root_path, alert: "❌ You are not authorized to return this record"
    end
  end

  def l2
  if current_user.hod?
    @employee_details = EmployeeDetail
                          .joins(user_details: :achievements)
                          .where(achievements: { status: ["l1_approved", "l2_approved", "l2_returned"] })
                          .includes(user_details: [:activity, :department, :achievements])
                          .distinct
                          .order(created_at: :desc)
  else
    @employee_details = EmployeeDetail
                          .joins(user_details: :achievements)
                          .where(achievements: { status: ["l1_approved", "l2_approved", "l2_returned"] })
                          .where("l2_code = ? OR l2_employer_name = ?", current_user.employee_code, current_user.email)
                          .includes(user_details: [:activity, :department, :achievements])
                          .distinct
                          .order(created_at: :desc)
  end

  # No need for separate quarterly grouping method since it's handled in the view
end

  def show_l2
    @employee_detail = EmployeeDetail.find(params[:id])
    
    unless current_user.hod? || can_act_as_l2?(@employee_detail)
      redirect_to root_path, alert: "❌ You are not authorized to access this page."
      return
    end
    
    @user_detail_id = params[:user_detail_id]
    @selected_quarter = params[:quarter]
    
    # Get all user details with achievements
    @user_details = @employee_detail.user_details
                      .includes(:activity, :department, :achievements)
                      .joins(:achievements)
                      .where.not(achievements: { achievement: [nil, ''] })
                      .distinct

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
    @employee_detail = EmployeeDetail.find(params[:id])
    
    unless current_user.hod? || can_act_as_l2?(@employee_detail)
      redirect_to show_l2_employee_detail_path(@employee_detail), alert: "❌ You are not authorized to approve at L2 level"
      return
    end

    result = process_quarterly_l2_approval

    if result[:success]
      redirect_to show_l2_employee_detail_path(@employee_detail, quarter: params[:selected_quarter]), 
                  notice: "✅ Successfully approved #{result[:count]} activities for #{params[:selected_quarter] || 'all quarters'} by L2"
    else
      redirect_to show_l2_employee_detail_path(@employee_detail, quarter: params[:selected_quarter]), 
                  alert: result[:message]
    end
  end

  def l2_return
    @employee_detail = EmployeeDetail.find(params[:id])

    unless current_user.hod? || can_act_as_l2?(@employee_detail)
      redirect_to show_l2_employee_detail_path(@employee_detail), alert: "❌ You are not authorized to return at L2 level"
      return
    end
    
    result = process_quarterly_l2_return

    if result[:success]
      redirect_to show_l2_employee_detail_path(@employee_detail, quarter: params[:selected_quarter]), 
                  alert: "⚠️ Successfully returned #{result[:count]} activities for #{params[:selected_quarter] || 'all quarters'} by L2"
    else
      redirect_to show_l2_employee_detail_path(@employee_detail, quarter: params[:selected_quarter]), 
                  alert: result[:message]
    end
  end

  private

  def set_employee_detail
    @employee_detail = EmployeeDetail.find(params[:id])
  end

  def employee_detail_params
    params.require(:employee_detail).permit(
      :employee_id, :employee_name, :employee_email, :employee_code, :mobile_number,
      :l1_code, :l1_employer_name, :l2_code, :l2_employer_name, 
      :post, :department, :l1_remarks, :l1_percentage, :l2_remarks, :l2_percentage
    )
  end

  def can_act_as_l1?(employee_detail)
    current_user.hod? || 
    current_user.employee_code == employee_detail.l1_code ||
    current_user.email == employee_detail.l1_employer_name
  end

  def can_act_as_l2?(employee_detail)
    current_user.hod? || 
    current_user.employee_code == employee_detail.l2_code ||
    current_user.email == employee_detail.l2_employer_name
  end

  def get_quarter_months(quarter)
    case quarter
    when 'Q1'
      ['january', 'february', 'march']
    when 'Q2'
      ['april', 'may', 'june']
    when 'Q3'
      ['july', 'august', 'september']
    when 'Q4'
      ['october', 'november', 'december']
    else
      []
    end
  end

  def get_all_quarters
    ['Q1', 'Q2', 'Q3', 'Q4']
  end

  # Group employees by quarters based on their achievements
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

    employee_details.each do |employee|
      get_all_quarters.each do |quarter|
        quarter_months = get_quarter_months(quarter)
        
        # Get achievements for this quarter
        quarter_achievements = employee.user_details.joins(:achievements)
                                      .where(achievements: { month: quarter_months })
                                      .where.not(achievements: { achievement: [nil, ''] })

        if quarter_achievements.any?
          employee_quarter_data = {
            employee: employee,
            activities: [],
            total_count: 0,
            pending_count: 0,
            approved_count: 0,
            overall_status: 'pending'
          }

          quarter_achievements.includes(:achievements, :activity, :department).each do |user_detail|
            user_detail.achievements.where(month: quarter_months).each do |achievement|
              next if achievement.achievement.blank?

              activity_data = {
                user_detail: user_detail,
                achievement: achievement,
                month: achievement.month,
                activity_name: user_detail.activity&.activity_name,
                department: user_detail.department&.department_type,
                target: get_target_for_month(user_detail, achievement.month),
                achievement_value: achievement.achievement,
                status: achievement.status || 'pending'
              }

              employee_quarter_data[:activities] << activity_data
              employee_quarter_data[:total_count] += 1
              
              case achievement.status
              when 'l1_approved', 'l2_approved'
                employee_quarter_data[:approved_count] += 1
              else
                employee_quarter_data[:pending_count] += 1
              end
            end
          end

          # Determine overall status for this employee in this quarter
          if employee_quarter_data[:approved_count] == employee_quarter_data[:total_count] && employee_quarter_data[:total_count] > 0
            employee_quarter_data[:overall_status] = 'approved'
          elsif employee_quarter_data[:pending_count] > 0
            employee_quarter_data[:overall_status] = 'pending'
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
    quarter_months = get_quarter_months(quarter)
    activities = []

    user_details.each do |user_detail|
      user_detail.achievements.where(month: quarter_months).each do |achievement|
        next if achievement.achievement.blank?

        activities << {
          user_detail: user_detail,
          achievement: achievement,
          month: achievement.month,
          activity_name: user_detail.activity&.activity_name,
          department: user_detail.department&.department_type,
          target: get_target_for_month(user_detail, achievement.month),
          achievement_value: achievement.achievement,
          status: achievement.status || 'pending',
          employee_remarks: achievement.employee_remarks
        }
      end
    end

    activities.sort_by { |a| [a[:month], a[:activity_name]] }
  end

  # Get all quarterly activities grouped by quarter
  def get_all_quarterly_activities(user_details)
    all_activities = {}
    
    get_all_quarters.each do |quarter|
      all_activities[quarter] = get_quarterly_activities(user_details, quarter)
    end

    all_activities
  end

  # Get target value for a specific month
  def get_target_for_month(user_detail, month)
    return nil unless user_detail.respond_to?(month.to_sym)
    user_detail.send(month.to_sym)
  end

  def process_quarterly_l1_approval
  approved_count = 0
  
  if params[:selected_quarter].present?
    # Approve specific quarter
    quarter_months = get_quarter_months(params[:selected_quarter])
    
    @employee_detail.user_details.each do |detail|
      achievements = detail.achievements.where(
        month: quarter_months,
        status: ['pending', 'l1_returned']
      ).where.not(achievement: [nil, ''])
      
      achievements.each do |achievement|
        achievement.update(status: 'l1_approved')
        
        # Create or update achievement remark with COMMON remarks for quarter
        remark = achievement.achievement_remark || achievement.build_achievement_remark
        remark.l1_remarks = params[:remarks] if params[:remarks].present?
        remark.l1_percentage = params[:percentage] if params[:percentage].present?
        remark.save!
        
        approved_count += 1
      end
    end
  else
    # Approve all quarters
    @employee_detail.user_details.each do |detail|
      achievements = detail.achievements.where(
        status: ['pending', 'l1_returned']
      ).where.not(achievement: [nil, ''])
      
      achievements.each do |achievement|
        achievement.update(status: 'l1_approved')
        
        remark = achievement.achievement_remark || achievement.build_achievement_remark
        remark.l1_remarks = params[:remarks] if params[:remarks].present?
        remark.l1_percentage = params[:percentage] if params[:percentage].present?
        remark.save!
        
        approved_count += 1
      end
    end
  end

  if approved_count > 0
    { success: true, count: approved_count }
  else
    { success: false, message: "❌ No activities found to approve for the selected quarter" }
  end
end

# Process L1 quarterly return - FIXED
def process_quarterly_l1_return
  returned_count = 0
  
  if params[:selected_quarter].present?
    # Return specific quarter
    quarter_months = get_quarter_months(params[:selected_quarter])
    
    @employee_detail.user_details.each do |detail|
      achievements = detail.achievements.where(
        month: quarter_months,
        status: ['pending', 'l1_approved']
      ).where.not(achievement: [nil, ''])
      
      achievements.each do |achievement|
        achievement.update(status: 'l1_returned')
        
        # Create or update achievement remark with COMMON remarks for quarter
        remark = achievement.achievement_remark || achievement.build_achievement_remark
        remark.l1_remarks = params[:remarks] if params[:remarks].present?
        remark.l1_percentage = params[:percentage] if params[:percentage].present?
        remark.save!
        
        returned_count += 1
      end
    end
  else
    # Return all quarters
    @employee_detail.user_details.each do |detail|
      achievements = detail.achievements.where(
        status: ['pending', 'l1_approved']
      ).where.not(achievement: [nil, ''])
      
      achievements.each do |achievement|
        achievement.update(status: 'l1_returned')
        
        remark = achievement.achievement_remark || achievement.build_achievement_remark
        remark.l1_remarks = params[:remarks] if params[:remarks].present?
        remark.l1_percentage = params[:percentage] if params[:percentage].present?
        remark.save!
        
        returned_count += 1
      end
    end
  end

  if returned_count > 0
    { success: true, count: returned_count }
  else
    { success: false, message: "❌ No activities found to return for the selected quarter" }
  end
end

# Process L2 quarterly approval - FIXED
def process_quarterly_l2_approval
  approved_count = 0
  
  if params[:selected_quarter].present?
    # Approve specific quarter
    quarter_months = get_quarter_months(params[:selected_quarter])
    
    @employee_detail.user_details.each do |detail|
      achievements = detail.achievements.where(
        month: quarter_months,
        status: ['l1_approved', 'l2_returned']
      ).where.not(achievement: [nil, ''])
      
      achievements.each do |achievement|
        achievement.update(status: 'l2_approved')
        
        # Create or update achievement remark with COMMON remarks for quarter
        remark = achievement.achievement_remark || achievement.build_achievement_remark
        remark.l2_remarks = params[:l2_remarks] || params[:remarks] if params[:l2_remarks].present? || params[:remarks].present?
        remark.l2_percentage = params[:l2_percentage] || params[:percentage] if params[:l2_percentage].present? || params[:percentage].present?
        remark.save!
        
        approved_count += 1
      end
    end
  else
    # Approve all quarters
    @employee_detail.user_details.each do |detail|
      achievements = detail.achievements.where(
        status: ['l1_approved', 'l2_returned']
      ).where.not(achievement: [nil, ''])
      
      achievements.each do |achievement|
        achievement.update(status: 'l2_approved')
        
        remark = achievement.achievement_remark || achievement.build_achievement_remark
        remark.l2_remarks = params[:l2_remarks] || params[:remarks] if params[:l2_remarks].present? || params[:remarks].present?
        remark.l2_percentage = params[:l2_percentage] || params[:percentage] if params[:l2_percentage].present? || params[:percentage].present?
        remark.save!
        
        approved_count += 1
      end
    end
  end

  if approved_count > 0
    { success: true, count: approved_count }
  else
    { success: false, message: "❌ No L1 approved activities found to approve for the selected quarter" }
  end
end

# Process L2 quarterly return - FIXED
def process_quarterly_l2_return
  returned_count = 0
  
  if params[:selected_quarter].present?
    # Return specific quarter
    quarter_months = get_quarter_months(params[:selected_quarter])
    
    @employee_detail.user_details.each do |detail|
      achievements = detail.achievements.where(
        month: quarter_months,
        status: ['l1_approved', 'l2_approved']
      ).where.not(achievement: [nil, ''])
      
      achievements.each do |achievement|
        achievement.update(status: 'l2_returned')
        
        # Create or update achievement remark with COMMON remarks for quarter
        remark = achievement.achievement_remark || achievement.build_achievement_remark
        remark.l2_remarks = params[:l2_remarks] || params[:remarks] if params[:l2_remarks].present? || params[:remarks].present?
        remark.l2_percentage = params[:l2_percentage] || params[:percentage] if params[:l2_percentage].present? || params[:percentage].present?
        remark.save!
        
        returned_count += 1
      end
    end
  else
    # Return all quarters
    @employee_detail.user_details.each do |detail|
      achievements = detail.achievements.where(
        status: ['l1_approved', 'l2_approved']
      ).where.not(achievement: [nil, ''])
      
      achievements.each do |achievement|
        achievement.update(status: 'l2_returned')
        
        remark = achievement.achievement_remark || achievement.build_achievement_remark
        remark.l2_remarks = params[:l2_remarks] || params[:remarks] if params[:l2_remarks].present? || params[:remarks].present?
        remark.l2_percentage = params[:l2_percentage] || params[:percentage] if params[:l2_percentage].present? || params[:percentage].present?
        remark.save!
        
        returned_count += 1
      end
    end
  end

  if returned_count > 0
    { success: true, count: returned_count }
  else
    { success: false, message: "❌ No approved activities found to return for the selected quarter" }
  end
end

end