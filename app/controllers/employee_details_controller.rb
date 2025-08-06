# # app/controllers/employee_details_controller.rb
# require 'roo'
# require 'axlsx'

# class EmployeeDetailsController < ApplicationController
#   before_action :set_employee_detail, only: [:edit, :update, :destroy]
#   load_and_authorize_resource except: [:approve, :return, :l2_approve, :l2_return]
  
#   def index
#     @employee_detail = EmployeeDetail.new
#     @q = EmployeeDetail.ransack(params[:q])
#     @employee_details = @q.result.order(created_at: :desc).page(params[:page]).per(10)
#   end

#   def create
#     @employee_detail = EmployeeDetail.new(employee_detail_params)
#     @employee_detail.user = current_user  # associate with logged-in user

#     @q = EmployeeDetail.ransack(params[:q])
#     if @employee_detail.save
#       redirect_to employee_details_path, notice: ' Employee created successfully.'
#     else
#       @employee_details = @q.result.order(created_at: :desc).page(params[:page]).per(10)
#       flash.now[:alert] = ' Failed to create employee.'
#       render :index, status: :unprocessable_entity
#     end
#   end

#   def update
#     if @employee_detail.update(employee_detail_params)
#       redirect_to employee_details_path, notice: 'Employee updated successfully.'
#     else
#       render :edit, status: :unprocessable_entity
#     end
#   end

#   def destroy
#     @employee_detail.destroy
#     redirect_to employee_details_path, notice: ' Employee deleted successfully.'
#   end

#   # ✅ EXPORT Excel
#   def export_xlsx
#     @employee_details = EmployeeDetail.all

#     package = Axlsx::Package.new
#     workbook = package.workbook

#     workbook.add_worksheet(name: "Employees") do |sheet|
#       sheet.add_row [
#         "Employee ID", "Name", "Email", "Employee Code",
#         "L1 Code", "L2 Code", "L1 Name", "L2 Name", "Post", "Department"
#       ]

#       @employee_details.each do |emp|
#         sheet.add_row [
#           emp.employee_id,
#           emp.employee_name,
#           emp.employee_email,
#           emp.employee_code,
#           emp.l1_code,
#           emp.l2_code,
#           emp.l1_employer_name,
#           emp.l2_employer_name,
#           emp.post,
#           emp.department
#         ]
#       end
#     end

#     tempfile = Tempfile.new(["employee_details", ".xlsx"])
#     package.serialize(tempfile.path)
#     send_file tempfile.path, filename: "employee_details.xlsx", type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
#   end

#     def import
#       file = params[:file]

#       if file.nil?
#         redirect_to employee_details_path, alert: 'Please upload a file.'
#         return
#       end

#       spreadsheet = Roo::Spreadsheet.open(file.path)
#       header = spreadsheet.row(1)

#       # Expected mapping between Excel headers and DB fields
#       header_map = {
#         "Employee ID" => "employee_id",
#         "Name" => "employee_name",
#         "Email" => "employee_email",
#         "Employee Code" => "employee_code",
#         "L1 Code" => "l1_code",
#         "L2 Code" => "l2_code",
#         "L1 Name" => "l1_employer_name",
#         "L2 Name" => "l2_employer_name",
#         "Post" => "post",
#         "Department" => "department"
#       }

#       (2..spreadsheet.last_row).each do |i|
#         row = Hash[[header, spreadsheet.row(i)].transpose]

#         # Map header keys to DB column names
#         mapped_row = row.transform_keys { |key| header_map[key] }.compact

#         # Debug in logs
#         puts "Creating Employee: #{mapped_row.inspect}"

#         begin
#           EmployeeDetail.create!(mapped_row)
#         rescue => e
#           puts "Import failed for row #{i}: #{e.message}"
#           next
#         end
#       end

#       redirect_to employee_details_path, notice: "✅ Employees imported successfully!"
#     end

#   def l1
#     authorize! :l1, EmployeeDetail

#     if current_user.hod?
#       # HOD sees all employees - let the view handle filtering for achievements
#       @employee_details = EmployeeDetail.includes(user_details: [:activity, :department, :achievements]).all
#     else
#       # L1 manager sees only their assigned employees
#       @employee_details = EmployeeDetail
#                             .where(status: ['pending', 'l1_returned', 'l1_approved', 'l2_returned', 'l2_approved'])
#                             .where(l1_code: current_user.employee_code)
#                             .includes(user_details: [:activity, :department, :achievements])
#     end
#   end

#     def show    
#       @employee_detail = EmployeeDetail.find(params[:id])
#       authorize! :read, @employee_detail
      
#       # Get the specific user_detail and month if provided
#       @user_detail_id = params[:user_detail_id]
#       @selected_month = params[:month]
      
#       if @user_detail_id.present?
#         # Show only the specific activity that was clicked
#         @user_details = @employee_detail.user_details
#                           .includes(:activity, :department, :achievements)
#                           .where(id: @user_detail_id)
#       else
#         # Show all activities with achievements (existing behavior)
#         @user_details = @employee_detail.user_details
#                           .includes(:activity, :department, :achievements)
#                           .select { |ud| ud.achievements.any? }
#       end

#       # Check if current user can approve or return (L1 level)
#       @can_approve_or_return = (
#         current_user.employee_code == @employee_detail.l1_code || 
#         current_user.email == @employee_detail.l1_employer_name
#       )
#     end

#     # def approve
#     #   @employee_detail = EmployeeDetail.find(params[:id])

#     #   if current_user.l1_employer? && @employee_detail.l1_code == current_user.employee_code
#     #     if params[:selected_month].present? && params[:user_detail_id].present?
#     #       # Approve only that month's activity
#     #       achievement = Achievement.find_by(user_detail_id: params[:user_detail_id], month: params[:selected_month])
#     #       if achievement
#     #         achievement.update(status: "l1_approved")
#     #         @employee_detail.update(
#     #           l1_remarks: params[:remarks],
#     #           l1_percentage: params[:percentage]
#     #         )
#     #       end
#     #     else
#     #       # Approve all (bulk)
#     #       @employee_detail.user_details.each do |detail|
#     #         detail.achievements.each do |ach|
#     #           ach.update(status: "l1_approved")
#     #         end
#     #       end
#     #       @employee_detail.update(
#     #         l1_remarks: params[:remarks],
#     #         l1_percentage: params[:percentage]
#     #       )
#     #     end
#     #     redirect_to l1_employee_details_path, notice: "✅ Approved"
      
#     #   elsif current_user.l2_employer? && @employee_detail.l2_code == current_user.employee_code
#     #     if params[:selected_month].present? && params[:user_detail_id].present?
#     #       achievement = Achievement.find_by(user_detail_id: params[:user_detail_id], month: params[:selected_month])
#     #       if achievement&.status == "l1_approved"
#     #         achievement.update(status: "l2_approved")
#     #         @employee_detail.update(
#     #           l2_remarks: params[:remarks],
#     #           l2_percentage: params[:percentage]
#     #         )
#     #       end
#     #     else
#     #       @employee_detail.user_details.each do |detail|
#     #         detail.achievements.where(status: "l1_approved").each do |ach|
#     #           ach.update(status: "l2_approved")
#     #         end
#     #       end
#     #       @employee_detail.update(
#     #         l2_remarks: params[:remarks],
#     #         l2_percentage: params[:percentage]
#     #       )
#     #     end
#     #     redirect_to l2_employee_details_path, notice: "✅ Approved by L2"
      
#     #   else
#     #     redirect_back fallback_location: root_path, alert: "❌ Not authorized"
#     #   end
#     # end

#     # def return
#     #   @employee_detail = EmployeeDetail.find(params[:id])

#     #   if current_user.l1_employer? && @employee_detail.l1_code == current_user.employee_code
#     #     if params[:selected_month].present? && params[:user_detail_id].present?
#     #       achievement = Achievement.find_by(user_detail_id: params[:user_detail_id], month: params[:selected_month])
#     #       if achievement
#     #         achievement.update(status: "l1_returned")
#     #         @employee_detail.update(
#     #           l1_remarks: params[:remarks],
#     #           l1_percentage: params[:percentage]
#     #         )
#     #       end
#     #     else
#     #       @employee_detail.user_details.each do |detail|
#     #         detail.achievements.each do |ach|
#     #           ach.update(status: "l1_returned")
#     #         end
#     #       end
#     #       @employee_detail.update(
#     #         l1_remarks: params[:remarks],
#     #         l1_percentage: params[:percentage]
#     #       )
#     #     end
#     #     redirect_to l1_employee_details_path, alert: "⚠️ Returned by L1"

#     #   elsif current_user.l2_employer? && @employee_detail.l2_code == current_user.employee_code
#     #     if params[:selected_month].present? && params[:user_detail_id].present?
#     #       achievement = Achievement.find_by(user_detail_id: params[:user_detail_id], month: params[:selected_month])
#     #       if achievement&.status == "l1_approved"
#     #         achievement.update(status: "l2_returned")
#     #         @employee_detail.update(
#     #           l2_remarks: params[:remarks],
#     #           l2_percentage: params[:percentage]
#     #         )
#     #       end
#     #     else
#     #       @employee_detail.user_details.each do |detail|
#     #         detail.achievements.where(status: "l1_approved").each do |ach|
#     #           ach.update(status: "l2_returned")
#     #         end
#     #       end
#     #       @employee_detail.update(
#     #         l2_remarks: params[:remarks],
#     #         l2_percentage: params[:percentage]
#     #       )
#     #     end
#     #     redirect_to l2_employee_details_path, alert: "⚠️ Returned by L2"
      
#     #   else
#     #     redirect_back fallback_location: root_path, alert: "❌ Not authorized"
#     #   end
#     # end
#     def approve
#       @employee_detail = EmployeeDetail.find(params[:id])

#       if current_user.l1_employer? && @employee_detail.l1_code == current_user.employee_code
#         process_approval(:l1_approved, :l1_remarks, :l1_percentage)
#         redirect_to l1_employee_details_path, notice: "✅ Approved by L1"
        
#       elsif current_user.l2_employer? && @employee_detail.l2_code == current_user.employee_code
#         achievement = find_achievement
#         if achievement&.status == "l1_approved"
#           process_approval(:l2_approved, :l2_remarks, :l2_percentage)
#           redirect_to l2_employee_details_path, notice: "✅ Approved by L2"
#         else
#           redirect_back fallback_location: root_path, alert: "❌ Not approved by L1 yet"
#         end

#       else
#         redirect_back fallback_location: root_path, alert: "❌ Not authorized"
#       end
#     end

#     def return
#       @employee_detail = EmployeeDetail.find(params[:id])

#       if current_user.l1_employer? && @employee_detail.l1_code == current_user.employee_code
#         process_return(:l1_returned, :l1_remarks, :l1_percentage)
#         redirect_to l1_employee_details_path, alert: "⚠️ Returned by L1"

#       elsif current_user.l2_employer? && @employee_detail.l2_code == current_user.employee_code
#         achievement = find_achievement
#         if achievement&.status == "l1_approved"
#           process_return(:l2_returned, :l2_remarks, :l2_percentage)
#           redirect_to l2_employee_details_path, alert: "⚠️ Returned by L2"
#         else
#           redirect_back fallback_location: root_path, alert: "❌ Not approved by L1 yet"
#         end

#       else
#         redirect_back fallback_location: root_path, alert: "❌ Not authorized"
#       end
#     end

#     def l2
#       if current_user.hod?
#         # HOD can see all employee details that have L1 approved achievements
#         @employee_details = EmployeeDetail
#                               .joins(user_details: :achievements)
#                               .where(achievements: { status: ["l1_approved", "l2_approved", "l2_returned"] })
#                               .includes(user_details: [:activity, :department, :achievements])
#                               .distinct
#                               .order(created_at: :desc)
#       else
#         # L2 officer sees their assigned employees with L1 approved achievements
#         @employee_details = EmployeeDetail
#                               .joins(user_details: :achievements)
#                               .where(achievements: { status: ["l1_approved", "l2_approved", "l2_returned"] })
#                               .where("l2_code = ? OR l2_employer_name = ?", current_user.employee_code, current_user.email)
#                               .includes(user_details: [:activity, :department, :achievements])
#                               .distinct
#                               .order(created_at: :desc)
#       end
#     end

#     def show_l2
#       @employee_detail = EmployeeDetail.find(params[:id])
      
#       # Manual authorization check instead of authorize!
#       unless current_user.hod? || 
#             current_user.l2_employer? && 
#             (current_user.employee_code == @employee_detail.l2_code || 
#               current_user.email == @employee_detail.l2_employer_name)
#         redirect_to root_path, alert: "❌ You are not authorized to access this page."
#         return
#       end
      
#       # Get the specific user_detail and month if provided (same as show method)
#       @user_detail_id = params[:user_detail_id]
#       @selected_month = params[:month]
      
#       if @user_detail_id.present?
#         @user_details = @employee_detail.user_details
#                           .includes(:activity, :department, :achievements)
#                           .where(id: @user_detail_id)
#       else
#         @user_details = @employee_detail.user_details
#                           .includes(:activity, :department, :achievements)
#                           .select { |ud| ud.achievements.any? }
#       end

#       # Fix: Change variable name to match what's used in the view
#       @can_l2_approve_or_return = (
#         (current_user.employee_code == @employee_detail.l2_code || 
#         current_user.email == @employee_detail.l2_employer_name ||
#         current_user.hod?)
#       )
      
#       # Keep the old variable for backward compatibility if needed elsewhere
#       @can_l2_act = @can_l2_approve_or_return
#     end 

#   def l2_approve
#     @employee_detail = EmployeeDetail.find(params[:id])
    
#     # Check authorization for L2 approval
#     unless (current_user.employee_code == @employee_detail.l2_code || 
#             current_user.email == @employee_detail.l2_employer_name || 
#             current_user.hod?)
#       redirect_to show_l2_employee_detail_path(@employee_detail), alert: "❌ You are not authorized to approve at L2 level"
#       return
#     end

#     # Handle specific month/activity approval
#     if params[:selected_month].present? && params[:user_detail_id].present?
#       achievement = Achievement.find_by(user_detail_id: params[:user_detail_id], month: params[:selected_month])
#       if achievement&.status == "l1_approved"
#         achievement.update(status: "l2_approved")
#         @employee_detail.update(
#           l2_remarks: params[:l2_remarks],
#           l2_percentage: params[:l2_percentage]
#         )
#         redirect_to show_l2_employee_detail_path(@employee_detail, user_detail_id: params[:user_detail_id], month: params[:selected_month]), notice: "✅ Successfully approved by L2"
#       else
#         redirect_to show_l2_employee_detail_path(@employee_detail, user_detail_id: params[:user_detail_id], month: params[:selected_month]), alert: "❌ Cannot approve - achievement not in correct status"
#       end
#     else
#       approved_count = 0
#       @employee_detail.user_details.each do |detail|
#         detail.achievements.where(status: "l1_approved").each do |achievement|
#           achievement.update(status: "l2_approved")
#           approved_count += 1
#         end
#       end
      
#       if approved_count > 0
#         @employee_detail.update(
#           l2_remarks: params[:l2_remarks],
#           l2_percentage: params[:l2_percentage]
#         )
#         redirect_to show_l2_employee_detail_path(@employee_detail), notice: "✅ Successfully approved #{approved_count} achievements by L2"
#       else
#         redirect_to show_l2_employee_detail_path(@employee_detail), alert: "❌ No achievements found to approve"
#       end
#     end
#   end

#   def l2_return
#     @employee_detail = EmployeeDetail.find(params[:id])

#     # Check authorization for L2 return
#     unless (current_user.employee_code == @employee_detail.l2_code || 
#             current_user.email == @employee_detail.l2_employer_name || 
#             current_user.hod?)
#       redirect_to show_l2_employee_detail_path(@employee_detail), alert: "❌ You are not authorized to return at L2 level"
#       return
#     end

#     # Handle specific month/activity return
#     if params[:selected_month].present? && params[:user_detail_id].present?
#       achievement = Achievement.find_by(user_detail_id: params[:user_detail_id], month: params[:selected_month])
#       if achievement&.status == "l1_approved"
#         achievement.update(status: "l2_returned")
#         @employee_detail.update(
#           l2_remarks: params[:l2_remarks],
#           l2_percentage: params[:l2_percentage]
#         )
#         redirect_to show_l2_employee_detail_path(@employee_detail, user_detail_id: params[:user_detail_id], month: params[:selected_month]), alert: "⚠️ Successfully returned by L2 with remarks"
#       else
#         redirect_to show_l2_employee_detail_path(@employee_detail, user_detail_id: params[:user_detail_id], month: params[:selected_month]), alert: "❌ Cannot return - achievement not in correct status"
#       end
#     else
#       # Bulk return all L1 approved achievements
#       returned_count = 0
#       @employee_detail.user_details.each do |detail|
#         detail.achievements.where(status: "l1_approved").each do |achievement|
#           achievement.update(status: "l2_returned")
#           returned_count += 1
#         end
#       end
      
#       if returned_count > 0
#         @employee_detail.update(
#           l2_remarks: params[:l2_remarks],
#           l2_percentage: params[:l2_percentage]
#         )
#         redirect_to show_l2_employee_detail_path(@employee_detail), alert: "⚠️ Successfully returned #{returned_count} achievements by L2 with remarks"
#       else
#         redirect_to show_l2_employee_detail_path(@employee_detail), alert: "❌ No achievements found to return"
#       end
#     end
#   end

#   private

#   def set_employee_detail
#     @employee_detail = EmployeeDetail.find(params[:id])
#   end

#   def employee_detail_params
#     params.require(:employee_detail).permit(
#       :employee_id, :employee_name, :employee_email, :employee_code,
#       :l1_code, :l1_employer_name, :l2_code, :l2_employer_name, :post, :department, :l1_remarks, :l1_percentage, :l2_remarks, :l2_percentage
#     )
#   end

#     def find_achievement
#     if params[:selected_month].present? && params[:user_detail_id].present?
#       Achievement.find_by(user_detail_id: params[:user_detail_id], month: params[:selected_month])
#     end
#   end

#   def process_approval(status, remark_key, percentage_key)
#     achievement = find_achievement
#     return unless achievement

#     achievement.update(status: status.to_s)
#     remark = achievement.achievement_remark || achievement.build_achievement_remark
#     remark.send("#{remark_key}=", params[:remarks])
#     remark.send("#{percentage_key}=", params[:percentage])
#     remark.save
#   end

#   def process_return(status, remark_key, percentage_key)
#     achievement = find_achievement
#     return unless achievement

#     achievement.update(status: status.to_s)
#     remark = achievement.achievement_remark || achievement.build_achievement_remark
#     remark.send("#{remark_key}=", params[:remarks])
#     remark.send("#{percentage_key}=", params[:percentage])
#     remark.save
#   end

# end



# app/controllers/employee_details_controller.rb
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
    @employee_detail.user = current_user  # associate with logged-in user

    @q = EmployeeDetail.ransack(params[:q])
    if @employee_detail.save
      redirect_to employee_details_path, notice: ' Employee created successfully.'
    else
      @employee_details = @q.result.order(created_at: :desc).page(params[:page]).per(10)
      flash.now[:alert] = ' Failed to create employee.'
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
    redirect_to employee_details_path, notice: ' Employee deleted successfully.'
  end

  # ✅ EXPORT Excel
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

    # Expected mapping between Excel headers and DB fields
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

      # Map header keys to DB column names
      mapped_row = row.transform_keys { |key| header_map[key] }.compact

      # Debug in logs
      puts "Creating Employee: #{mapped_row.inspect}"

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
      # HOD sees all employees - let the view handle filtering for achievements
      @employee_details = EmployeeDetail.includes(user_details: [:activity, :department, :achievements]).all
    else
      # L1 manager sees only their assigned employees
      @employee_details = EmployeeDetail
                            .where(status: ['pending', 'l1_returned', 'l1_approved', 'l2_returned', 'l2_approved'])
                            .where(l1_code: current_user.employee_code)
                            .includes(user_details: [:activity, :department, :achievements])
    end
  end

  def show    
    @employee_detail = EmployeeDetail.find(params[:id])
    authorize! :read, @employee_detail
    
    # Get the specific user_detail and month if provided
    @user_detail_id = params[:user_detail_id]
    @selected_month = params[:month]
    
    if @user_detail_id.present?
      # Show only the specific activity that was clicked
      @user_details = @employee_detail.user_details
                        .includes(:activity, :department, :achievements)
                        .where(id: @user_detail_id)
    else
      # Show all activities with achievements (existing behavior)
      @user_details = @employee_detail.user_details
                        .includes(:activity, :department, :achievements)
                        .select { |ud| ud.achievements.any? }
    end

    # Check if current user can approve or return (L1 level)
    @can_approve_or_return = (
      current_user.employee_code == @employee_detail.l1_code || 
      current_user.email == @employee_detail.l1_employer_name
    )
  end

  # L1 Approve Method
  def approve
    @employee_detail = EmployeeDetail.find(params[:id])

    if current_user.l1_employer? && @employee_detail.l1_code == current_user.employee_code
      process_approval(:l1_approved, :l1_remarks, :l1_percentage)
      redirect_to l1_employee_details_path, notice: "✅ Approved by L1"
      
    elsif current_user.l2_employer? && @employee_detail.l2_code == current_user.employee_code
      achievement = find_achievement
      if achievement&.status == "l1_approved"
        process_approval(:l2_approved, :l2_remarks, :l2_percentage)
        redirect_to l2_employee_details_path, notice: "✅ Approved by L2"
      else
        redirect_back fallback_location: root_path, alert: "❌ Not approved by L1 yet"
      end

    else
      redirect_back fallback_location: root_path, alert: "❌ Not authorized"
    end
  end

  # L1 Return Method
  def return
    @employee_detail = EmployeeDetail.find(params[:id])

    if current_user.l1_employer? && @employee_detail.l1_code == current_user.employee_code
      process_return(:l1_returned, :l1_remarks, :l1_percentage)
      redirect_to l1_employee_details_path, alert: "⚠️ Returned by L1"

    elsif current_user.l2_employer? && @employee_detail.l2_code == current_user.employee_code
      achievement = find_achievement
      if achievement&.status == "l1_approved"
        process_return(:l2_returned, :l2_remarks, :l2_percentage)
        redirect_to l2_employee_details_path, alert: "⚠️ Returned by L2"
      else
        redirect_back fallback_location: root_path, alert: "❌ Not approved by L1 yet"
      end

    else
      redirect_back fallback_location: root_path, alert: "❌ Not authorized"
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
    
    # Manual authorization check instead of authorize!
    unless current_user.hod? || 
          current_user.l2_employer? && 
          (current_user.employee_code == @employee_detail.l2_code || 
            current_user.email == @employee_detail.l2_employer_name)
      redirect_to root_path, alert: "❌ You are not authorized to access this page."
      return
    end
    
    # Get the specific user_detail and month if provided (same as show method)
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

    @can_l2_approve_or_return = (
      (current_user.employee_code == @employee_detail.l2_code || 
      current_user.email == @employee_detail.l2_employer_name ||
      current_user.hod?)
    )
    
    @can_l2_act = @can_l2_approve_or_return
  end 

  def l2_approve
    @employee_detail = EmployeeDetail.find(params[:id])
    
    unless (current_user.employee_code == @employee_detail.l2_code || 
            current_user.email == @employee_detail.l2_employer_name || 
            current_user.hod?)
      redirect_to show_l2_employee_detail_path(@employee_detail), alert: "❌ You are not authorized to approve at L2 level"
      return
    end

    if params[:selected_month].present? && params[:user_detail_id].present?
      achievement = Achievement.find_by(user_detail_id: params[:user_detail_id], month: params[:selected_month])
      if achievement&.status == "l1_approved"
        achievement.update(status: "l2_approved")
        
        remark = achievement.achievement_remark || achievement.build_achievement_remark
        remark.l2_remarks = params[:l2_remarks]
        remark.l2_percentage = params[:l2_percentage]
        remark.save
        
        redirect_to show_l2_employee_detail_path(@employee_detail, user_detail_id: params[:user_detail_id], month: params[:selected_month]), notice: "✅ Successfully approved by L2"
      else
        redirect_to show_l2_employee_detail_path(@employee_detail, user_detail_id: params[:user_detail_id], month: params[:selected_month]), alert: "❌ Cannot approve - achievement not in correct status"
      end
    else
      approved_count = 0
      @employee_detail.user_details.each do |detail|
        detail.achievements.where(status: "l1_approved").each do |achievement|
          achievement.update(status: "l2_approved")
          
          remark = achievement.achievement_remark || achievement.build_achievement_remark
          remark.l2_remarks = params[:l2_remarks]
          remark.l2_percentage = params[:l2_percentage]
          remark.save
          
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

    # Check authorization for L2 return
    unless (current_user.employee_code == @employee_detail.l2_code || 
            current_user.email == @employee_detail.l2_employer_name || 
            current_user.hod?)
      redirect_to show_l2_employee_detail_path(@employee_detail), alert: "❌ You are not authorized to return at L2 level"
      return
    end

    # Handle specific month/activity return
    if params[:selected_month].present? && params[:user_detail_id].present?
      achievement = Achievement.find_by(user_detail_id: params[:user_detail_id], month: params[:selected_month])
      if achievement&.status == "l1_approved"
        achievement.update(status: "l2_returned")
        
        # Create or update achievement remark with L2 data
        remark = achievement.achievement_remark || achievement.build_achievement_remark
        remark.l2_remarks = params[:l2_remarks]
        remark.l2_percentage = params[:l2_percentage]
        remark.save
        
        redirect_to show_l2_employee_detail_path(@employee_detail, user_detail_id: params[:user_detail_id], month: params[:selected_month]), alert: "⚠️ Successfully returned by L2 with remarks"
      else
        redirect_to show_l2_employee_detail_path(@employee_detail, user_detail_id: params[:user_detail_id], month: params[:selected_month]), alert: "❌ Cannot return - achievement not in correct status"
      end
    else
      # Bulk return all L1 approved achievements
      returned_count = 0
      @employee_detail.user_details.each do |detail|
        detail.achievements.where(status: "l1_approved").each do |achievement|
          achievement.update(status: "l2_returned")
          
          # Create or update achievement remark with L2 data
          remark = achievement.achievement_remark || achievement.build_achievement_remark
          remark.l2_remarks = params[:l2_remarks]
          remark.l2_percentage = params[:l2_percentage]
          remark.save
          
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
      :l1_code, :l1_employer_name, :l2_code, :l2_employer_name, :post, :department, :l1_remarks, :l1_percentage, :l2_remarks, :l2_percentage
    )
  end

  def find_achievement
    if params[:selected_month].present? && params[:user_detail_id].present?
      Achievement.find_by(user_detail_id: params[:user_detail_id], month: params[:selected_month])
    end
  end

  def process_approval(status, remark_key, percentage_key)
    achievement = find_achievement
    return unless achievement

    achievement.update(status: status.to_s)
    remark = achievement.achievement_remark || achievement.build_achievement_remark
    remark.send("#{remark_key}=", params[:remarks])
    remark.send("#{percentage_key}=", params[:percentage])
    remark.save
  end

  def process_return(status, remark_key, percentage_key)
    achievement = find_achievement
    return unless achievement

    achievement.update(status: status.to_s)
    remark = achievement.achievement_remark || achievement.build_achievement_remark
    remark.send("#{remark_key}=", params[:remarks])
    remark.send("#{percentage_key}=", params[:percentage])
    remark.save
  end
end