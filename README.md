# KRA (Key Result Area) Management System

## Overview
A comprehensive web application for managing employee Key Result Areas (KRAs), tracking achievements, and managing multi-level approval workflows. The system supports monthly and quarterly achievement tracking with a hierarchical approval process.

---

## 1. ROLE-BASED ACCESS CONTROL

### 1.1 Employee Role
**Access Level:** Limited to own data
- ✅ View own employee details
- ✅ Submit monthly achievements
- ✅ Submit quarterly achievements (Q1, Q2, Q3, Q4)
- ✅ View own submitted achievements
- ✅ Edit own achievements (before approval)
- ✅ View own approval status
- ❌ Cannot view other employees' data
- ❌ Cannot approve or return achievements
- ❌ Cannot access dashboard statistics

**Default Redirect:** `/user_details/get_user_detail` (Employee Achievement Form)

---

### 1.2 L1 Employer (Level 1 Approver)
**Access Level:** First-level approval authority
- ✅ View employees assigned under their L1 code or email
- ✅ View achievements with status: `pending`, `l1_returned`, `l1_approved`, `l2_returned`, `l2_approved`
- ✅ Approve achievements at L1 level
- ✅ Return achievements to employees with remarks
- ✅ Access L1 approval view (`/employee_details/l1`)
- ✅ View submitted achievements of assigned employees
- ❌ Cannot approve at L2 or L3 level
- ❌ Cannot view L3-only data

**Default Redirect:** `/employee_details/l1` (L1 Approval View)

**Approval Workflow:**
- Can approve achievements in status: `pending`, `l1_returned`
- After approval, status changes to `l1_approved`
- Can return achievements with remarks, status changes to `l1_returned`

---

### 1.3 L2 Employer (Level 2 Approver)
**Access Level:** Second-level approval authority
- ✅ View employees assigned under their L2 code or email
- ✅ View achievements with status: `l1_approved`, `l2_returned`, `l2_approved`
- ✅ Approve achievements at L2 level
- ✅ Return achievements to L1 or employee with remarks
- ✅ Access L2 approval view (`/employee_details/l2`)
- ✅ View submitted achievements of assigned employees
- ❌ Cannot approve at L1 or L3 level
- ❌ Cannot view pending (unapproved by L1) achievements

**Default Redirect:** `/employee_details/l2` (L2 Approval View)

**Approval Workflow:**
- Can approve achievements in status: `l1_approved`, `l2_returned`
- After approval, status changes to `l2_approved`
- Can return achievements with remarks, status changes to `l2_returned`

---

### 1.4 L3 Employer (Level 3 Approver)
**Access Level:** Final approval authority
- ✅ View employees assigned under their L3 code or email
- ✅ View achievements with status: `l2_approved`, `l3_returned`, `l3_approved`
- ✅ Approve achievements at L3 level (final approval)
- ✅ Return achievements to L2, L1, or employee with remarks
- ✅ Access L3 approval view (`/employee_details/l3`)
- ✅ View submitted achievements of assigned employees
- ❌ Cannot approve at L1 or L2 level
- ❌ Cannot view achievements not yet approved by L2

**Default Redirect:** `/employee_details/l3` (L3 Approval View)

**Approval Workflow:**
- Can approve achievements in status: `l2_approved`, `l3_returned`
- After approval, status changes to `l3_approved` (final)
- Can return achievements with remarks, status changes to `l3_returned`

---

### 1.5 HOD (Head of Department)
**Access Level:** Full system access (Super Admin)
- ✅ **Full access to all features**
- ✅ View all employees and their data
- ✅ View all achievements regardless of status
- ✅ Access main dashboard with statistics
- ✅ Manage departments
- ✅ Manage activities
- ✅ Import/Export employee data
- ✅ Import/Export department data
- ✅ View all approval workflows
- ✅ Access settings
- ✅ View SMS logs
- ✅ Test SMS and Email functionality
- ✅ Override any approval level (if needed)

**Default Redirect:** `/dashboard` (Main Dashboard)

**Special Permissions:**
- Can view and manage all data in the system
- No restrictions on any feature
- Can access all approval levels simultaneously

---

## 2. AUTHENTICATION & USER MANAGEMENT

### 2.1 User Registration
- **Location:** `/users/sign_up`
- **Features:**
  - Email-based registration
  - Employee code assignment
  - Role assignment (employee, hod, l1_employer, l2_employer)
  - Password creation
  - Avatar upload support

### 2.2 User Login
- **Location:** `/users/sign_in`
- **Features:**
  - Login with email OR employee code
  - Password authentication
  - Remember me functionality
  - Automatic redirect based on role

### 2.3 Password Management
- **Password Reset:** `/users/password/new`
- **Password Change:** `/settings/password`
- **Features:**
  - Email-based password reset
  - Secure password change in settings
  - Password recovery via email

---

## 3. EMPLOYEE MANAGEMENT

### 3.1 Employee Details
- **Location:** `/employee_details`
- **Features:**
  - Create new employee records
  - View employee list
  - Edit employee information
  - Delete employee records
  - Search and filter employees
  - Assign L1, L2, L3 approvers
  - Set employee code, email, name, post, department
  - Mobile number management

### 3.2 Employee Import/Export
- **Import:** `/employee_details/import`
  - Bulk import from Excel file
  - Template download available
  - Validates data before import
  - Creates user accounts automatically
  
- **Export:** `/employee_details/export_xlsx`
  - Export all employee data to Excel
  - Includes all employee details
  - Quarterly data export available

### 3.3 Employee Account Creation
- **Automatic:** When employee_detail is created, user account is automatically created
- **Default Password:** `123456`
- **Default Role:** `employee`
- **Login:** Can login with email or employee_code

---

## 4. DEPARTMENT MANAGEMENT

### 4.1 Department Creation
- **Location:** `/departments/new`
- **Features:**
  - Create new departments
  - Set department type
  - Assign employee reference
  - Add activities to department
  - Multiple employees per department support

### 4.2 Department Activities
- **Location:** `/departments/:id/activities`
- **Features:**
  - Add activities to department
  - Set activity name
  - Set theme name
  - Set weight and unit
  - Edit activity details
  - Delete activities

### 4.3 Department Employee Management
- **Add Employee:** Assign employees to departments
- **Remove Employee:** Remove specific employee from department (Orange button)
- **Delete Department:** Remove entire department and all data (Red button)
- **Features:**
  - Multiple employees per department
  - Multiple departments per employee
  - Automatic UserDetail creation for activities

### 4.4 Department Import/Export
- **Import:** `/departments/import`
  - Bulk import departments and activities
  - Excel template support
  
- **Export:** `/departments/export`
  - Export department structure
  - Include activities and employee assignments

### 4.5 Department Activity List
- **Location:** `/departments/activity_list`
- **Features:**
  - View all activities across departments
  - Filter by department
  - View activity assignments

---

## 5. ACTIVITY MANAGEMENT

### 5.1 Activity Structure
- **Components:**
  - Activity Name
  - Theme Name
  - Weight (importance)
  - Unit (measurement unit)
  - Department association

### 5.2 Activity Assignment
- Activities are assigned to employees through departments
- Each employee-department-activity combination creates a UserDetail record
- Supports multiple activities per employee

---

## 6. ACHIEVEMENT SUBMISSION

### 6.1 Monthly Achievement Submission
- **Location:** `/user_details/get_user_detail` (for employees)
- **Features:**
  - Submit achievements by month
  - Months: January, February, March, April, May, June, July, August, September, October, November, December
  - Enter achievement value
  - View target/weight for each activity
  - Submit multiple activities at once
  - Edit before approval

### 6.2 Quarterly Achievement Submission
- **Location:** `/user_details/quarterly_edit_all`
- **Features:**
  - Submit achievements by quarter (Q1, Q2, Q3, Q4)
  - Quarterly format: `q1`, `q2`, `q3`, `q4`
  - Bulk edit all quarterly achievements
  - Update multiple quarters at once
  - View quarterly targets

### 6.3 Achievement Status
- **Status Flow:**
  1. `pending` - Initial submission
  2. `l1_approved` - Approved by L1
  3. `l2_approved` - Approved by L2
  4. `l3_approved` - Final approval
  5. `l1_returned` - Returned by L1
  6. `l2_returned` - Returned by L2
  7. `l3_returned` - Returned by L3
  8. `returned_to_employee` - Returned to employee for correction

### 6.4 Achievement Submission Process
1. Employee selects department and activity
2. Employee enters achievement value for month/quarter
3. System validates data
4. Achievement status set to `pending`
5. Notification sent to L1 approver
6. Achievement appears in L1 approval queue

---

## 7. APPROVAL WORKFLOW

### 7.1 L1 Approval Process
- **Location:** `/employee_details/l1`
- **View:** `/employee_details/:id` (for L1 approvers)
- **Features:**
  - View pending achievements assigned to L1
  - View employee details and activities
  - View achievement values
  - Add L1 remarks
  - Set L1 percentage
  - Approve achievement (status → `l1_approved`)
  - Return to employee (status → `l1_returned`)
  - Email notification to L2 on approval

### 7.2 L2 Approval Process
- **Location:** `/employee_details/l2`
- **View:** `/employee_details/:id/show_l2` (for L2 approvers)
- **Features:**
  - View L1-approved achievements
  - View L1 remarks and percentage
  - Add L2 remarks
  - Set L2 percentage
  - Approve achievement (status → `l2_approved`)
  - Return to L1 or employee (status → `l2_returned`)
  - Email notification to L3 on approval

### 7.3 L3 Approval Process
- **Location:** `/employee_details/l3`
- **View:** `/employee_details/:id/show_l3` (for L3 approvers)
- **Features:**
  - View L2-approved achievements
  - View L1 and L2 remarks and percentages
  - Add L3 remarks
  - Set L3 percentage
  - Approve achievement (status → `l3_approved`) - Final approval
  - Return to L2, L1, or employee (status → `l3_returned`)
  - Email notification to employee on final approval

### 7.4 Approval Remarks
- **L1 Remarks:** Added by L1 approver
- **L2 Remarks:** Added by L2 approver
- **L3 Remarks:** Added by L3 approver
- **Employee Remarks:** Added by employee when resubmitting
- All remarks are visible in the approval chain

### 7.5 Return Workflow
- **L1 Return:** Achievement returned to employee
- **L2 Return:** Can return to L1 or employee
- **L3 Return:** Can return to L2, L1, or employee
- **Employee Edit:** Employee can edit and resubmit returned achievements
- **Status Reset:** When returned, employee can edit and status resets to `pending`

---

## 8. QUARTERLY TRACKING

### 8.1 Quarterly Achievement Management
- **Location:** `/user_details/quarterly_edit_all`
- **Features:**
  - View all quarterly achievements (Q1, Q2, Q3, Q4)
  - Bulk edit quarterly data
  - Update multiple quarters simultaneously
  - View quarterly targets
  - Submit quarterly achievements

### 8.2 Quarterly Approval
- Quarterly achievements follow same approval workflow as monthly
- L1, L2, L3 can approve quarterly achievements
- Quarterly format: `q1`, `q2`, `q3`, `q4`
- Monthly format: Individual months (april, may, june for Q1, etc.)

### 8.3 Quarterly Export
- **Location:** `/employee_details/export_quarterly_xlsx`
- **Features:**
  - Export quarterly L1 and L2 approval data
  - Includes quarterly achievements and approvals
  - Excel format

---

## 9. DASHBOARD & STATISTICS

### 9.1 Main Dashboard (HOD Only)
- **Location:** `/dashboard`
- **Features:**
  - Total users count
  - Total employees count
  - Total departments count
  - Total activities count
  - L1 approved count (by quarter)
  - L2 approved count (by quarter)
  - L3 approved count (by quarter)
  - L1 returned count
  - L2 returned count
  - L3 returned count
  - L1 pending count
  - L2 pending count
  - L3 pending count
  - Total achievements count
  - Role-based user counts

### 9.2 Submitted View Data
- **Location:** `/submitted_view_data`
- **Features:**
  - View all submitted achievements
  - Filter by role (employee sees own, HOD sees all)
  - View monthly and quarterly achievements
  - Real-time status updates
  - Filter by department and activity

### 9.3 Quarterly Details
- **Location:** `/quarterly_details`
- **Features:**
  - View quarterly summaries
  - L1, L2, L3 level summaries
  - Percentage calculations
  - Status overview by quarter

---

## 10. USER DETAILS MANAGEMENT

### 10.1 User Details View
- **Location:** `/user_details`
- **Features:**
  - View employee-activity-department assignments
  - View achievement history
  - Edit user details
  - Delete user details

### 10.2 Bulk Operations
- **Bulk Create:** `/user_details/bulk_create`
  - Create multiple user details at once
  
- **Bulk Upload:** `/user_details/bulk_upload`
  - Upload user details from Excel
  
- **Import:** `/user_details/import`
  - Import user details with activities

### 10.3 Export Functions
- **Export:** `/user_details/export`
  - Export user details to Excel
  
- **Export Excel:** `/user_details/export_excel`
  - Detailed Excel export with achievements
  
- **Export Department Activity:** `/user_details/export_department_activity`
  - Export by department and activity

### 10.4 Template Download
- **Location:** `/user_details/download_template`
- **Features:**
  - Download Excel template for bulk upload
  - Pre-formatted with required columns

---

## 11. NOTIFICATIONS

### 11.1 Email Notifications
- **L1 Approval Request:** Sent to L1 when employee submits
- **L2 Approval Request:** Sent to L2 when L1 approves
- **L3 Approval Request:** Sent to L3 when L2 approves
- **Achievement Approved:** Sent to employee on final approval
- **Achievement Returned:** Sent to employee when returned
- **Quarterly Notifications:** Similar workflow for quarterly achievements

### 11.2 SMS Notifications
- **SMS Service:** Integrated SMS service for notifications
- **SMS Logs:** `/user_details/view_sms_logs`
  - View all SMS sent
  - Track SMS delivery
  - Clear SMS tracking
  
- **Test SMS:** `/user_details/test_sms`
  - Test SMS functionality
  
- **Test Email:** `/user_details/test_email`
  - Test email functionality

### 11.3 Notification Types
- Achievement submission confirmation
- Approval notifications
- Return notifications
- Final approval notifications
- Quarterly submission confirmations

---

## 12. SETTINGS

### 12.1 User Settings
- **Location:** `/settings`
- **Features:**
  - Update profile information
  - Change password
  - Update email
  - Update employee code
  - Avatar management

### 12.2 Profile Management
- **Update Profile:** `/settings/profile`
  - PATCH request to update profile
  
- **Change Password:** `/settings/password`
  - PATCH request to change password
  - Requires current password

---

## 13. DATA EXPORT & IMPORT

### 13.1 Employee Data Export
- **Format:** Excel (.xlsx)
- **Includes:**
  - Employee details
  - Department assignments
  - Activity assignments
  - Achievement data
  - Approval status

### 13.2 Department Data Export
- **Format:** Excel (.xlsx)
- **Includes:**
  - Department structure
  - Activities
  - Employee assignments
  - Activity details

### 13.3 Achievement Data Export
- **Format:** Excel (.xlsx)
- **Includes:**
  - Monthly achievements
  - Quarterly achievements
  - Approval remarks
  - Approval percentages
  - Status information

### 13.4 Import Features
- **Employee Import:** Bulk import from Excel
- **Department Import:** Bulk import departments and activities
- **User Details Import:** Import activity assignments
- **Validation:** Data validation before import
- **Error Handling:** Reports import errors

---

## 14. SEARCH & FILTERING

### 14.1 Employee Search
- Search by employee name
- Search by employee code
- Search by email
- Filter by department
- Filter by status
- Filter by L1/L2/L3 assignee

### 14.2 Achievement Filtering
- Filter by status
- Filter by month/quarter
- Filter by department
- Filter by activity
- Filter by approval level

---

## 15. TECHNICAL FEATURES

### 15.1 Real-Time Updates
- **AJAX Status Updates:** `/employee_details/:id/get_status`
  - Real-time status updates without page refresh
  - Dynamic approval status display

### 15.2 Performance Optimizations
- Counter caches for achievements
- Eager loading of associations
- Database indexes on key fields
- Optimized queries for large datasets

### 15.3 Security Features
- Role-based access control (CanCanCan)
- Authentication required for all actions
- Data filtering by user role
- Secure password handling
- Email/employee code validation

---

## 16. WORKFLOW SUMMARY

### 16.1 Complete Approval Flow
1. **Employee Submission:**
   - Employee logs in
   - Selects department and activity
   - Enters achievement value (monthly/quarterly)
   - Submits achievement
   - Status: `pending`
   - Email sent to L1

2. **L1 Approval:**
   - L1 receives notification
   - Reviews achievement
   - Adds remarks and percentage
   - Approves or returns
   - If approved: Status → `l1_approved`, Email to L2
   - If returned: Status → `l1_returned`, Email to employee

3. **L2 Approval:**
   - L2 receives notification (if L1 approved)
   - Reviews L1 remarks and achievement
   - Adds L2 remarks and percentage
   - Approves or returns
   - If approved: Status → `l2_approved`, Email to L3
   - If returned: Status → `l2_returned`, Email to L1/employee

4. **L3 Approval:**
   - L3 receives notification (if L2 approved)
   - Reviews L1, L2 remarks and achievement
   - Adds L3 remarks and percentage
   - Approves or returns
   - If approved: Status → `l3_approved` (FINAL), Email to employee
   - If returned: Status → `l3_returned`, Email to L2/L1/employee

5. **Employee Resubmission (if returned):**
   - Employee receives return notification
   - Reviews approver remarks
   - Edits achievement
   - Resubmits
   - Status resets to `pending`
   - Process repeats

---

## 17. QUARTERLY WORKFLOW

### 17.1 Quarterly Quarters
- **Q1:** April, May, June (or `q1`)
- **Q2:** July, August, September (or `q2`)
- **Q3:** October, November, December (or `q3`)
- **Q4:** January, February, March (or `q4`)

### 17.2 Quarterly Submission
- Employees can submit quarterly achievements
- Same approval workflow applies
- Quarterly data tracked separately from monthly

---

## 18. KEY FEATURES SUMMARY

✅ **Multi-level Approval System** (L1 → L2 → L3)
✅ **Role-based Access Control** (Employee, L1, L2, L3, HOD)
✅ **Monthly & Quarterly Tracking**
✅ **Department & Activity Management**
✅ **Bulk Import/Export** (Excel)
✅ **Email & SMS Notifications**
✅ **Real-time Status Updates**
✅ **Dashboard Statistics** (HOD)
✅ **Search & Filtering**
✅ **Remarks & Percentage Tracking**
✅ **Return & Resubmission Workflow**
✅ **User Account Auto-creation**
✅ **Multiple Departments per Employee**
✅ **Multiple Activities per Employee**

---

## 19. SYSTEM REQUIREMENTS

- **Framework:** Ruby on Rails
- **Database:** PostgreSQL (or configured database)
- **Authentication:** Devise
- **Authorization:** CanCanCan
- **File Processing:** Axlsx (Excel)
- **Email:** ActionMailer
- **SMS:** Integrated SMS Service

---

## 20. USAGE GUIDE

### For Employees:
1. Login with email or employee code
2. Navigate to achievement form
3. Select department and activity
4. Enter achievement value
5. Submit for approval
6. Check status and remarks
7. Edit and resubmit if returned

### For L1 Approvers:
1. Login with L1 credentials
2. Navigate to L1 approval view
3. Review pending achievements
4. Add remarks and percentage
5. Approve or return

### For L2 Approvers:
1. Login with L2 credentials
2. Navigate to L2 approval view
3. Review L1-approved achievements
4. Add L2 remarks and percentage
5. Approve or return

### For L3 Approvers:
1. Login with L3 credentials
2. Navigate to L3 approval view
3. Review L2-approved achievements
4. Add L3 remarks and percentage
5. Approve (final) or return

### For HOD:
1. Login with HOD credentials
2. Access dashboard for overview
3. Manage departments and activities
4. Import/export data
5. View all approvals and statistics
6. Manage system settings

---

**End of Documentation**
