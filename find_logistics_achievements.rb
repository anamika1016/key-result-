#!/usr/bin/env ruby

# Load Rails environment
require_relative 'config/environment'

puts "Finding Logistics achievements..."

# Find all Logistics achievements for Anamika
logistics_achievements = Achievement.joins(user_detail: :employee_detail)
  .where(employee_details: { employee_name: "Anamika Vishwakarma" })
  .joins(user_detail: :department)
  .where(departments: { department_type: "Logistics" })

puts "Logistics achievements for Anamika: #{logistics_achievements.count}"

logistics_achievements.each do |ach|
  employee_name = ach.user_detail.employee_detail.employee_name
  department = ach.user_detail.department.department_type
  user_detail_id = ach.user_detail_id
  employee_detail_id = ach.user_detail.employee_detail_id

  puts "  - UserDetail ID: #{user_detail_id}, EmployeeDetail ID: #{employee_detail_id}"
  puts "    #{ach.month}: #{ach.status} - '#{ach.achievement}'"
end

# Also check all achievements with 'q1' month for Anamika
puts "\nAll 'q1' achievements for Anamika:"
q1_achievements = Achievement.joins(user_detail: :employee_detail)
  .where(employee_details: { employee_name: "Anamika Vishwakarma" })
  .where(month: 'q1')

q1_achievements.each do |ach|
  employee_name = ach.user_detail.employee_detail.employee_name
  department = ach.user_detail.department.department_type
  user_detail_id = ach.user_detail_id
  employee_detail_id = ach.user_detail.employee_detail_id

  puts "  - UserDetail ID: #{user_detail_id}, EmployeeDetail ID: #{employee_detail_id}"
  puts "    Department: #{department}, #{ach.month}: #{ach.status} - '#{ach.achievement}'"
end

puts "\nSearch completed."
