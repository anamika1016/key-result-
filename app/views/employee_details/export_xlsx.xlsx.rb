package = Axlsx::Package.new
workbook = package.workbook

workbook.add_worksheet(name: "Employees") do |sheet|
  sheet.add_row [ "Employee Code", "Name", "Email", "Department" ]
  @employee_details.each do |emp|
    sheet.add_row [
      emp.employee_code,
      emp.employee_name,
      emp.employee_email,
      emp.department
    ]
  end
end

# Set response headers and render file
tempfile = Tempfile.new([ "employee_details", ".xlsx" ])
package.serialize(tempfile.path)

send_file tempfile.path, filename: "employee_details.xlsx", type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
