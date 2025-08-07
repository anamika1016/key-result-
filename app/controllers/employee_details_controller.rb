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
  end

  def show    
    @employee_detail = EmployeeDetail.find(params[:id])
    authorize! :read, @employee_detail
    
    @user_detail_id = params[:user_detail_id]
    @selected_month = params[:month]
    
    if @user_detail_id.present?
      @user_details = @employee_detail.user_details
                        .includes(:activity, :department, :achievements)
                        .where(id: @user_detail_id)
    else
      @user_details = @employee_detail.user_details
                        .includes(:activity, :department, :achievements)
                        .select { |ud| ud.achievements.any? }
    end

    # Fixed authorization logic - check if current user can approve/return at L1 level
    @can_approve_or_return = can_act_as_l1?(@employee_detail)
  end

  # L1 Approve Method - FIXED
  def approve
    @employee_detail = EmployeeDetail.find(params[:id])

    Rails.logger.debug "=== APPROVE DEBUG ==="
    Rails.logger.debug "Current User: #{current_user.inspect}"
    Rails.logger.debug "Current User Employee Code: #{current_user.employee_code}"
    Rails.logger.debug "Employee Detail L1 Code: #{@employee_detail.l1_code}"
    Rails.logger.debug "Can Act as L1?: #{can_act_as_l1?(@employee_detail)}"
    Rails.logger.debug "Can Act as L2?: #{can_act_as_l2?(@employee_detail)}"
    Rails.logger.debug "Params: #{params.inspect}"

    # Check if user can approve at L1 level
    if can_act_as_l1?(@employee_detail)
      Rails.logger.debug "PROCESSING L1 APPROVAL"
      process_l1_approval
      redirect_to employee_detail_path(@employee_detail, month: params[:selected_month], user_detail_id: params[:user_detail_id]), 
                  notice: "✅ Successfully approved by L1"
    
    # Check if user can approve at L2 level  
    elsif can_act_as_l2?(@employee_detail)
      Rails.logger.debug "PROCESSING L2 APPROVAL"
      achievement = find_achievement
      if achievement&.status == "l1_approved"
        process_l2_approval
        redirect_to employee_detail_path(@employee_detail, month: params[:selected_month], user_detail_id: params[:user_detail_id]), 
                    notice: "✅ Successfully approved by L2"
      else
        Rails.logger.debug "L2 APPROVAL FAILED - NOT L1 APPROVED"
        redirect_back fallback_location: root_path, alert: "❌ Achievement must be L1 approved first"
      end
    else
      Rails.logger.debug "AUTHORIZATION FAILED"
      redirect_back fallback_location: root_path, alert: "❌ You are not authorized to approve this record"
    end
  end

  # L1 Return Method - FIXED
  def return
    @employee_detail = EmployeeDetail.find(params[:id])

    Rails.logger.debug "=== RETURN DEBUG ==="
    Rails.logger.debug "Current User Employee Code: #{current_user.employee_code}"
    Rails.logger.debug "Employee Detail L1 Code: #{@employee_detail.l1_code}"
    Rails.logger.debug "Can Act as L1?: #{can_act_as_l1?(@employee_detail)}"
    Rails.logger.debug "Can Act as L2?: #{can_act_as_l2?(@employee_detail)}"

    # Check if user can return at L1 level
    if can_act_as_l1?(@employee_detail)
      Rails.logger.debug "PROCESSING L1 RETURN"
      process_l1_return
      redirect_to employee_detail_path(@employee_detail, month: params[:selected_month], user_detail_id: params[:user_detail_id]), 
                  alert: "⚠️ Successfully returned by L1"

    # Check if user can return at L2 level
    elsif can_act_as_l2?(@employee_detail)
      Rails.logger.debug "PROCESSING L2 RETURN"
      achievement = find_achievement
      if achievement&.status == "l1_approved"
        process_l2_return
        redirect_to employee_detail_path(@employee_detail, month: params[:selected_month], user_detail_id: params[:user_detail_id]), 
                    alert: "⚠️ Successfully returned by L2"
      else
        Rails.logger.debug "L2 RETURN FAILED - NOT L1 APPROVED"
        redirect_back fallback_location: root_path, alert: "❌ Achievement must be L1 approved first"
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
  end

  def show_l2
    @employee_detail = EmployeeDetail.find(params[:id])
    
    unless current_user.hod? || can_act_as_l2?(@employee_detail)
      redirect_to root_path, alert: "❌ You are not authorized to access this page."
      return
    end
    
    @user_detail_id = params[:user_detail_id]
    @selected_month = params[:month]
    
    if @user_detail_id.present?
      @user_details = @employee_detail.user_details
                        .includes(:activity, :department, :achievements)
                        .where(id: @user_detail_id)
    else
      @user_details = @employee_detail.user_details
                        .includes(:activity, :department, :achievements)
                        .select { |ud| ud.achievements.any? }
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

    # FIXED: Use correct parameter names that match the form
    Rails.logger.debug "=== L2 APPROVE DEBUG ==="
    Rails.logger.debug "Params: #{params.inspect}"
    Rails.logger.debug "L2 Remarks: #{params[:l2_remarks]}"
    Rails.logger.debug "L2 Percentage: #{params[:l2_percentage]}"

    if params[:selected_month].present? && params[:user_detail_id].present?
      achievement = Achievement.find_by(user_detail_id: params[:user_detail_id], month: params[:selected_month])
      if achievement&.status == "l1_approved"
        achievement.update(status: "l2_approved")
        
        remark = achievement.achievement_remark || achievement.build_achievement_remark
        remark.l2_remarks = params[:l2_remarks]  # FIXED: Use l2_remarks instead of remarks
        remark.l2_percentage = params[:l2_percentage]  # FIXED: Use l2_percentage instead of percentage
        remark.save!  # FIXED: Use save! to raise errors if save fails
        
        Rails.logger.debug "L2 Remark saved: #{remark.inspect}"
        
        redirect_to show_l2_employee_detail_path(@employee_detail, user_detail_id: params[:user_detail_id], month: params[:selected_month]), 
                    notice: "✅ Successfully approved by L2"
      else
        redirect_to show_l2_employee_detail_path(@employee_detail, user_detail_id: params[:user_detail_id], month: params[:selected_month]), 
                    alert: "❌ Cannot approve - achievement not in correct status"
      end
    else
      approved_count = 0
      @employee_detail.user_details.each do |detail|
        detail.achievements.where(status: "l1_approved").each do |achievement|
          achievement.update(status: "l2_approved")
          
          remark = achievement.achievement_remark || achievement.build_achievement_remark
          remark.l2_remarks = params[:l2_remarks]  # FIXED: Use l2_remarks instead of remarks
          remark.l2_percentage = params[:l2_percentage]  # FIXED: Use l2_percentage instead of percentage
          remark.save!  # FIXED: Use save! to raise errors if save fails
          
          approved_count += 1
        end
      end
      
      if approved_count > 0
        redirect_to show_l2_employee_detail_path(@employee_detail), notice: "✅ Successfully approved #{approved_count} achievements by L2"
      else
        redirect_to show_l2_employee_detail_path(@employee_detail), alert: "❌ No achievements found to approve"
      end
    end
  end

  def l2_return
    @employee_detail = EmployeeDetail.find(params[:id])

    unless current_user.hod? || can_act_as_l2?(@employee_detail)
      redirect_to show_l2_employee_detail_path(@employee_detail), alert: "❌ You are not authorized to return at L2 level"
      return
    end

    # FIXED: Use correct parameter names that match the form
    Rails.logger.debug "=== L2 RETURN DEBUG ==="
    Rails.logger.debug "Params: #{params.inspect}"
    Rails.logger.debug "L2 Remarks: #{params[:l2_remarks]}"
    Rails.logger.debug "L2 Percentage: #{params[:l2_percentage]}"

    if params[:selected_month].present? && params[:user_detail_id].present?
      achievement = Achievement.find_by(user_detail_id: params[:user_detail_id], month: params[:selected_month])
      if achievement&.status == "l1_approved"
        achievement.update(status: "l2_returned")
        
        remark = achievement.achievement_remark || achievement.build_achievement_remark
        remark.l2_remarks = params[:l2_remarks]  # FIXED: Use l2_remarks instead of remarks
        remark.l2_percentage = params[:l2_percentage]  # FIXED: Use l2_percentage instead of percentage
        remark.save!  # FIXED: Use save! to raise errors if save fails
        
        Rails.logger.debug "L2 Remark saved: #{remark.inspect}"
        
        redirect_to show_l2_employee_detail_path(@employee_detail, user_detail_id: params[:user_detail_id], month: params[:selected_month]), 
                    alert: "⚠️ Successfully returned by L2 with remarks"
      else
        redirect_to show_l2_employee_detail_path(@employee_detail, user_detail_id: params[:user_detail_id], month: params[:selected_month]), 
                    alert: "❌ Cannot return - achievement not in correct status"
      end
    else
      returned_count = 0
      @employee_detail.user_details.each do |detail|
        detail.achievements.where(status: "l1_approved").each do |achievement|
          achievement.update(status: "l2_returned")
          
          remark = achievement.achievement_remark || achievement.build_achievement_remark
          remark.l2_remarks = params[:l2_remarks]  # FIXED: Use l2_remarks instead of remarks
          remark.l2_percentage = params[:l2_percentage]  # FIXED: Use l2_percentage instead of percentage
          remark.save!  # FIXED: Use save! to raise errors if save fails
          
          returned_count += 1
        end
      end
      
      if returned_count > 0
        redirect_to show_l2_employee_detail_path(@employee_detail), alert: "⚠️ Successfully returned #{returned_count} achievements by L2 with remarks"
      else
        redirect_to show_l2_employee_detail_path(@employee_detail), alert: "❌ No achievements found to return"
      end
    end
  end

  private

  def set_employee_detail
    @employee_detail = EmployeeDetail.find(params[:id])
  end

  def employee_detail_params
    params.require(:employee_detail).permit(
      :employee_id, :employee_name, :employee_email, :employee_code,
      :l1_code, :l1_employer_name, :l2_code, :l2_employer_name, :post, :department, 
      :l1_remarks, :l1_percentage, :l2_remarks, :l2_percentage
    )
  end

  # FIXED: Authorization helper methods
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

  def find_achievement
    if params[:selected_month].present? && params[:user_detail_id].present?
      Achievement.find_by(user_detail_id: params[:user_detail_id], month: params[:selected_month])
    end
  end

  # FIXED: L1 Processing Methods
  def process_l1_approval
    if params[:selected_month].present? && params[:user_detail_id].present?
      # Single month approval
      achievement = find_achievement
      return unless achievement && ['pending', 'l1_returned'].include?(achievement.status)

      achievement.update(status: 'l1_approved')
      remark = achievement.achievement_remark || achievement.build_achievement_remark
      remark.l1_remarks = params[:remarks]
      remark.l1_percentage = params[:percentage]
      remark.save!  # FIXED: Use save! to ensure it saves
    else
      # Bulk approval for all pending/returned achievements
      @employee_detail.user_details.each do |detail|
        detail.achievements.where(status: ['pending', 'l1_returned']).each do |achievement|
          achievement.update(status: 'l1_approved')
          remark = achievement.achievement_remark || achievement.build_achievement_remark
          remark.l1_remarks = params[:remarks]
          remark.l1_percentage = params[:percentage]
          remark.save!  # FIXED: Use save! to ensure it saves
        end
      end
    end
  end

  def process_l1_return
    if params[:selected_month].present? && params[:user_detail_id].present?
      # Single month return
      achievement = find_achievement
      return unless achievement && ['pending', 'l1_returned'].include?(achievement.status)

      achievement.update(status: 'l1_returned')
      remark = achievement.achievement_remark || achievement.build_achievement_remark
      remark.l1_remarks = params[:remarks]
      remark.l1_percentage = params[:percentage]
      remark.save!  # FIXED: Use save! to ensure it saves
    else
      # Bulk return for all pending achievements
      @employee_detail.user_details.each do |detail|
        detail.achievements.where(status: ['pending']).each do |achievement|
          achievement.update(status: 'l1_returned')
          remark = achievement.achievement_remark || achievement.build_achievement_remark
          remark.l1_remarks = params[:remarks]
          remark.l1_percentage = params[:percentage]
          remark.save!  # FIXED: Use save! to ensure it saves
        end
      end
    end
  end

  # FIXED: L2 Processing Methods
  def process_l2_approval
    if params[:selected_month].present? && params[:user_detail_id].present?
      achievement = find_achievement
      return unless achievement && achievement.status == 'l1_approved'

      achievement.update(status: 'l2_approved')
      remark = achievement.achievement_remark || achievement.build_achievement_remark
      remark.l2_remarks = params[:remarks]
      remark.l2_percentage = params[:percentage]
      remark.save!  # FIXED: Use save! to ensure it saves
    else
      @employee_detail.user_details.each do |detail|
        detail.achievements.where(status: 'l1_approved').each do |achievement|
          achievement.update(status: 'l2_approved')
          remark = achievement.achievement_remark || achievement.build_achievement_remark
          remark.l2_remarks = params[:remarks]
          remark.l2_percentage = params[:percentage]
          remark.save!  # FIXED: Use save! to ensure it saves
        end
      end
    end
  end

  def process_l2_return
    if params[:selected_month].present? && params[:user_detail_id].present?
      achievement = find_achievement
      return unless achievement && achievement.status == 'l1_approved'

      achievement.update(status: 'l2_returned')
      remark = achievement.achievement_remark || achievement.build_achievement_remark
      remark.l2_remarks = params[:remarks]
      remark.l2_percentage = params[:percentage]
      remark.save!  # FIXED: Use save! to ensure it saves
    else
      @employee_detail.user_details.each do |detail|
        detail.achievements.where(status: 'l1_approved').each do |achievement|
          achievement.update(status: 'l2_returned')
          remark = achievement.achievement_remark || achievement.build_achievement_remark
          remark.l2_remarks = params[:remarks]
          remark.l2_percentage = params[:percentage]
          remark.save!  # FIXED: Use save! to ensure it saves
        end
      end
    end
  end
end