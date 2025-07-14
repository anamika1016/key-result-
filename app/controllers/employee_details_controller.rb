# app/controllers/employee_details_controller.rb
require 'roo'
require 'axlsx'

class EmployeeDetailsController < ApplicationController
  before_action :set_employee_detail, only: [:edit, :update, :destroy]

  def index
    @employee_detail = EmployeeDetail.new
    @q = EmployeeDetail.ransack(params[:q])
    @employee_details = @q.result.order(created_at: :desc).page(params[:page]).per(10)
  end

  def create
    @employee_detail = EmployeeDetail.new(employee_detail_params)
    if @employee_detail.save
      redirect_to employee_details_path, notice: '✅ Employee created successfully.'
    else
      @employee_details = EmployeeDetail.page(params[:page])
      flash.now[:alert] = '❌ Failed to create employee.'
      render :index, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @employee_detail.update(employee_detail_params)
      redirect_to employee_details_path, notice: '✅ Employee updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @employee_detail.destroy
    redirect_to employee_details_path, notice: '✅ Employee deleted successfully.'
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
      redirect_to employee_details_path, alert: '❌ Please upload a file.'
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
      puts "✅ Creating Employee: #{mapped_row.inspect}"

      begin
        EmployeeDetail.create!(mapped_row)
      rescue => e
        puts "❌ Import failed for row #{i}: #{e.message}"
        next
      end
    end

    redirect_to employee_details_path, notice: "✅ Employees imported successfully!"
  end

  def l1
    @employee_details = EmployeeDetail.all
  end

def l2
  # Show only records approved by L1 or already handled by L2
  @employee_details = EmployeeDetail.where(status: ["approved", "l2_returned", "l2_approved"]).order(created_at: :desc)
end





  def show
    @employee_detail = EmployeeDetail.find_by(id: params[:id])

    if @employee_detail.nil?
      redirect_to employee_details_path, alert: "Employee not found."
      return
    end

    @user_details = @employee_detail.user_details.includes(:department, :activity)
  end

  def approve
    @employee_detail = EmployeeDetail.find(params[:id])
    @employee_detail.update(status: "approved")
    redirect_to employee_detail_path(@employee_detail), notice: "✅ Approved successfully."
  end

  def return
    @employee_detail = EmployeeDetail.find(params[:id])
    @employee_detail.update(status: "returned")
    redirect_to employee_detail_path(@employee_detail), alert: "🔁 Returned successfully."
  end

 def show_l2
    @employee_detail = EmployeeDetail.find(params[:id])
    @user_details = @employee_detail.user_details
  end

  def l2_approve
    @employee_detail = EmployeeDetail.find(params[:id])
    @employee_detail.update(status: "l2_approved")
    redirect_to show_l2_employee_detail_path(@employee_detail), notice: "✅ Approved by L2 successfully."
  end

  def l2_return
    @employee_detail = EmployeeDetail.find(params[:id])
    @employee_detail.update(status: "l2_returned")
    redirect_to show_l2_employee_detail_path(@employee_detail), alert: "🔁 Returned by L2 successfully."
  end

  private

  def set_employee_detail
    @employee_detail = EmployeeDetail.find(params[:id])
  end

  def employee_detail_params
    params.require(:employee_detail).permit(
      :employee_id, :employee_name, :employee_email, :employee_code,
      :l1_code, :l1_employer_name, :l2_code, :l2_employer_name, :post, :department
    )
  end
end
