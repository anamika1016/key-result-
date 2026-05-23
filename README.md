# KRA (Key Result Area) Management System

## Overview
A comprehensive web application for managing employee Key Result Areas (KRAs), tracking achievements, and managing multi-level approval workflows. The system supports monthly and quarterly achievement tracking with a hierarchical approval process.

---

## 🛠 TECHNOLOGY STACK

*   **Language:** Ruby
*   **Framework:** Ruby on Rails
*   **Database:** PostgreSQL
*   **Frontend UI:** HTML, CSS, JavaScript, jQuery
*   **Deployment:** Kamal (with Docker)

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

## HELP DESK MODULE - MENU WISE ROLE & WORKFLOW

Help Desk module complaint aur suggestion handling ke liye use hota hai. Isme employee request raise karta hai, escalation matrix ke according ticket reviewer ke paas jata hai, reviewer response deta hai, aur final action user ke login se close/reopen ya approve/reject hota hai.

### 1. HELP DESK Menu
**Route:** `/help-desk`

**Ye menu sabhi logged-in users ko dikhta hai.**

**Employee / Requester ka work:**
- Apni complaint ya suggestion submit kar sakta hai.
- Department/Vertical select karta hai.
- Request Type me `Complaint` ya `Suggestion` select karta hai.
- Common Question / Topic select kar sakta hai; agar topic available nahi hai to `Other` me custom topic likh sakta hai.
- Complaint/Suggestion details aur supporting documents upload kar sakta hai.
- Maximum 5 documents upload ho sakte hain, har file 10MB tak.
- Current Requests me apne active tickets dekh sakta hai.
- Jab support ticket complete mark karta hai, requester ke paas final action aata hai:
  - `Close` / `Approve`: ticket close ho jayega.
  - `Reopen` / `Reject`: ticket remark ke saath support ko wapas chala jayega.

**Manager / Help Desk Reviewer ka work:**
- Agar user escalation matrix me kisi department ke L1/L2/L3 support owner ke roop me assigned hai, to uske HELP DESK page par `Assigned Queue` dikhegi.
- Assigned ticket par reviewer response/update add karta hai.
- `Keep Open`: ticket support ke paas open rahega aur due time reset ho jayega.
- `Close Ticket`: ticket requester/original submitter ke final action ke liye bheja jayega.
- Reviewer action ke baad user ko 2 din ka action window milta hai.

**HOD ka work:**
- HOD help desk ke saare tickets dekh/handle kar sakta hai.
- HOD kisi bhi open review ticket par response de sakta hai, kyunki HOD ko full access hai.
- HOD ke liye current tickets, assigned/support status aur final user action tracking visible hoti hai.

**Oral Complaint / Suggestion Response Ticket:**
- HELP DESK form me `Create response ticket for an oral complaint / suggestion` option available hai.
- Is mode me logged-in user kisi employee ke behalf par completed oral request ka response ticket create karta hai.
- Employee ko final `Approve / Reject` action milta hai.
- Reject karne par ticket remark ke saath reopen hota hai.

**Important status flow:**
- `submitted`: ticket submit ho gaya.
- `in_review`: support/reviewer ke paas work in progress hai.
- `reopened`: user ne response reject/reopen kiya.
- `resolved`: support ne complete mark kiya, user action pending hai.
- `closed`: user ne close/approve kiya ya 2 din tak action na dene par auto close/auto approve hua.

**Time rules:**
- Support reviewer ko response ke liye 2 din milte hain.
- Agar response nahi aata to ticket next escalation level par move hota hai.
- User ko final close/reopen ya approve/reject ke liye 2 din milte hain.
- User action nahi karta to ticket automatically closed/approved ho jata hai.

### 2. Help Desk Report Menu
**Route:** `/helpdesk-report`

**Ye menu sabhi logged-in users ko dikhta hai, lekin data role-wise filter hota hai.**

**Employee / Requester:**
- Apne raised tickets, apne behalf par raised tickets, assigned tickets, aur resolved-by-you tickets ka history dekh sakta hai.
- Closed tickets HELP DESK current list se nikal kar report me saved rahte hain.

**Reviewer / Manager:**
- Jo tickets usko assigned hue, usne respond kiye, ya uske visibility scope me hain, unka report dekh sakta hai.

**HOD:**
- Sabhi departments ke all help desk tickets ka complete report dekh sakta hai.

**Report features:**
- Ticket number, requester, employee code, topic, message, support update, remark se search.
- Department, Request Type aur Status filter.
- Print Report.
- Download Excel.
- Full ticket trail: requester, submitted by, assigned owner, response, user remark, reopen count, close time.

### 3. Help Desk Question Master Menu
**Route:** `/helpdesk-question-master`

**Ye menu sirf HOD ko dikhta hai.**

**Iska kaam:**
- Department/Vertical wise common help desk questions/topics create karna.
- Request Type wise question maintain karna:
  - Complaint questions
  - Suggestion questions
- Display order set karna.
- Question active/inactive karna.
- Existing question edit/delete karna.

**HELP DESK form me iska use:**
- Employee jab department aur request type select karta hai, to yahi master questions dropdown me show hote hain.
- Agar matching topic nahi hai to employee custom topic type kar sakta hai.

### 4. Helpdesk Escalation Matrix Menu
**Route:** `/helpdesk-escalation-matrix`

**Ye menu sirf HOD ko dikhta hai.**

**Iska kaam:**
- Har Department/Vertical ke liye escalation chain configure karna.
- L1, L2, L3 ya jitne dynamic levels chahiye utne support owners assign karna.
- Escalation level add/remove/reorder karna.
- Matrix edit/delete karna.

**Ticket routing me iska use:**
- Employee self ticket submit karta hai to selected department ki matrix ke first level user ko ticket assign hota hai.
- Agar first owner 2 din me response nahi deta, ticket next escalation level par move hota hai.
- Har department ke liye matrix required hai. Matrix nahi hogi to us department ka help desk ticket create nahi hoga.

### Role Wise Short Summary

| Role | HELP DESK | Report | Question Master | Escalation Matrix |
| --- | --- | --- | --- | --- |
| Employee | Complaint/Suggestion raise, own current tickets, final close/reopen or approve/reject | Own visible ticket history | No access | No access |
| L1/L2 Manager or Assigned Reviewer | Own request raise, assigned queue respond, keep open/close ticket | Assigned/responded/visible tickets | No access | No access |
| HOD | All tickets view/respond, full support control | All tickets report | Create/edit/delete questions | Create/edit/delete escalation matrix |

### Complete Help Desk Flow
1. HOD `Helpdesk Escalation Matrix` me department wise escalation users set karega.
2. HOD `Help Desk Question Master` me department aur complaint/suggestion wise common topics set karega.
3. Employee `HELP DESK` menu se ticket raise karega.
4. Ticket selected department ke first escalation user ko assign hoga.
5. Reviewer ticket par update dega:
   - Work pending ho to `Keep Open`.
   - Work complete ho to `Close Ticket`.
6. User ke login me final action aayega:
   - Normal self ticket: `Reopen` ya `Close`.
   - Oral response ticket: `Reject` ya `Approve`.
7. Closed ticket current HELP DESK list se nikal kar `Help Desk Report` me saved history ke roop me dikhega.

---

## TRAINING MODULE - MENU WISE ROLE & WORKFLOW

Training module employee learning PPT/document upload, employee-wise assignment, training completion tracking, assessment, aur certificate generation ke liye use hota hai.

### 1. TRAININGS Menu
**Route:** `/trainings`

**Ye menu sabhi logged-in users ko dikhta hai.**

**Employee / L1 / L2 user ka work:**
- Assigned/visible trainings list dekh sakta hai.
- Training cards month aur year wise grouped dikhte hain.
- Month, Year aur Training Title se filter kar sakta hai.
- Active training par `Start Training` karke PPT/document view kar sakta hai.
- Required duration complete hone ke baad training complete kar sakta hai.
- Agar training me assessment enabled hai to duration complete hone ke baad assessment dena padta hai.
- Assessment submit hone par score save hota hai.
- Completed training par status, completed date, time spent, score aur financial year dikhte hain.
- Month ke saare assigned/visible trainings complete hone ke baad monthly certificate download kar sakta hai.
- Inactive training card dikh sakta hai, lekin non-HOD user usko open/start nahi kar sakta.

**HOD ka work:**
- Training list me all trainings dekh sakta hai, active aur inactive dono.
- `Upload New Training` button se new training create kar sakta hai.
- Training ka title, description, required duration, month, year, status aur files upload kar sakta hai.
- PPT/PDF/DOC/DOCX type training files attach kar sakta hai.
- Assessment enable karke questions manually add kar sakta hai.
- Assessment questions Excel template se upload/import kar sakta hai.
- Existing training `View`, `Edit`, `Activate/Deactivate`, aur `Delete` kar sakta hai.
- HOD inactive training bhi open/view kar sakta hai.

**Training completion rules:**
- User ko required duration jitna time training page par spend karna hota hai.
- Time spent system me save hota hai.
- Required time complete hone ke baad:
  - Without assessment: training directly completed ho jati hai.
  - With assessment: user assessment page par jata hai, answers submit karta hai, score save hota hai.
- Monthly certificate tabhi generate hota hai jab us month ke saare assigned/visible trainings completed hon aur required time bhi complete ho.

### 2. ASSIGN TRAININGS Menu
**Route:** `/user_training_assignments`

**Ye menu sirf HOD ko dikhta hai.**

**Iska kaam:**
- Employee-wise training assignment manage karna.
- All employees ki training completion summary dekhna.
- Total Training, Total Users, Total Completed aur Total Pending count dekhna.
- Month, Year aur Training Title ke basis par dashboard stats filter karna.
- Employee name, email ya employee code se search karna.
- Kisi employee ke liye `Assign PPTs` button se specific trainings select/unselect karna.
- Employee ke assigned trainings aur completion progress ko `View Progress` se dekhna.
- All employee training data Excel me export karna.

**Assignment behavior:**
- Agar HOD ne kisi employee ke assignments explicitly manage nahi kiye hain, to employee ko default behavior ke according trainings visible rahte hain.
- Jab HOD employee ke liye assignment save karta hai, employee `HOD-managed` ho jata hai.
- HOD-managed employee ko sirf selected/assigned trainings hi dikhte hain.
- New training upload hone par already HOD-managed employees ko new training auto-assign hoti hai, taki latest PPT unki assignment list me available rahe.

### 3. Training Progress / Certificate View
**Route examples:**
- Employee detail progress: `/user_training_assignments/:employee_detail_id`
- Monthly certificate: `/trainings/monthly_certificate/:year/:month`
- Single training certificate: `/trainings/:id/certificate`

**HOD ka work:**
- Employee-wise assigned trainings ka progress dekh sakta hai.
- Har training ka completed/pending status, duration, score aur completion date check kar sakta hai.
- Employee ke monthly certificate ko view/download kar sakta hai, agar month ke saare required trainings complete hain.

**Employee ka work:**
- Apne login se completed month ka certificate download kar sakta hai.
- Completed training ko `View Again` se dobara open kar sakta hai.

### Role Wise Short Summary

| Role | TRAININGS | ASSIGN TRAININGS | Progress / Certificate |
| --- | --- | --- | --- |
| Employee | Assigned/visible trainings start, complete, assessment submit, monthly certificate download | No access | Own completion status and certificate |
| L1/L2 Manager | Employee jaise apne assigned/visible trainings complete kar sakta hai | No access | Own completion status and certificate |
| HOD | Upload, edit, view, activate/deactivate, delete trainings, manage assessment | Full access, employee-wise assignment and export | All employees progress and certificate view |

### Complete Training Flow
1. HOD `TRAININGS` menu me training upload karega.
2. HOD training files, duration, month, year aur assessment questions set karega.
3. HOD `ASSIGN TRAININGS` menu se employee-wise PPT/training assign karega.
4. Employee `TRAININGS` menu me assigned/visible training open karega.
5. Employee required duration complete karega.
6. Agar assessment enabled hai to employee assessment submit karega.
7. Training completed status me save hogi.
8. Month ke sabhi assigned/visible trainings complete hone ke baad monthly certificate available hoga.
9. HOD `ASSIGN TRAININGS` menu se employee-wise completion report aur Excel export dekh sakta hai.

---

## QUIZ MODULE - MENU WISE ROLE & WORKFLOW

Quiz module assessment create karne, QR/public link se employee quiz conduct karne, score save karne, aur completed quiz history track karne ke liye use hota hai.

### 1. Quiz Details Menu
**Route:** `/quizzes`

**Ye menu sirf HOD ko dikhta hai.**

**HOD ka work:**
- All quizzes list dekh sakta hai.
- Total quizzes, active quizzes aur total questions count dekh sakta hai.
- `Add New Quiz` se naya quiz create kar sakta hai.
- Quiz title, description, duration aur status set kar sakta hai.
- Status `active` ya `inactive` rakh sakta hai.
- Har quiz me multiple questions add kar sakta hai.
- Har question ke 4 options set kar sakta hai: Option A, Option B, Option C, Option D.
- Correct answer select/set kar sakta hai.
- Existing quiz ko `View QR`, `Edit`, aur `Delete` kar sakta hai.
- Excel upload se quiz aur questions import kar sakta hai.
- Quiz list/questions Excel me export kar sakta hai.

**Quiz duration:**
- Duration seconds, minutes, ya hours me set ho sakta hai.
- Example: `30 seconds`, `5 minutes`, `1 hour`.
- Public quiz screen par timer show hota hai.

**QR / Public Link ka use:**
- Quiz create hone ke baad `View QR` page par QR code generate hota hai.
- Same page par public quiz link bhi show hota hai.
- Employee QR scan karke ya link open karke quiz login screen par jata hai.

**Active / Inactive rule:**
- `active` quiz QR/public link se open hota hai.
- `inactive` quiz public side par unavailable show hota hai.

### 2. User Quiz Details Menu
**Route:** `/user_quizzes`

**Ye menu sirf HOD ko dikhta hai.**

**Iska kaam:**
- Quiz attempt ke liye employee access records maintain karna.
- Employee Code, Name, Email, Mobile Number, Designation, Branch, Sub Branch aur Password save karna.
- Employee quiz entry manually add/edit/delete karna.
- Excel se employee quiz users bulk import karna.
- User quiz template download karna.
- User quiz entries Excel me export karna.
- Employee code, name, email, mobile, branch ya sub-branch se search karna.
- Saved User Quiz Entries me employee password aur linked user details dekhna.
- Completed Quiz History me submitted quiz score aur status dekhna.

**Important fields:**
- `Employee Code`: quiz login ke liye required.
- `Password`: quiz login ke liye required.
- `Name` aur `Email`: report/history ke liye required.
- Employee code unique hota hai; same code par record update ho sakta hai.

**Completed Quiz History:**
- QR/public link se submit hua quiz yahan save hota hai.
- Quiz title, employee code, name, designation, score, status aur submitted time show hota hai.
- Export Excel me user entries aur completed quiz history dono sheets me aate hain.

### 3. Public Quiz Access
**Route:** `/quiz_access/:qr_token`

**Ye normal sidebar menu nahi hai. Ye QR code/public link se open hota hai.**

**Employee / Participant ka work:**
- QR scan ya public quiz link open karega.
- ESS Employee Code aur Password enter karega.
- Password wahi hota hai jo HOD ne `User Quiz Details` me set kiya hai.
- Login successful hone par quiz questions open honge.
- Questions random order me show hote hain.
- Har question ke 4 options me se ek answer select karna hota hai.
- Timer enabled hai to remaining time screen par dikhta hai.
- `Submit Quiz` par score calculate hoke save hota hai.

**Attempt rule:**
- Ek employee code ek quiz ko ek baar submit kar sakta hai.
- Submit ke baad same employee ko "already submitted" message aur score dikh sakta hai.

**Score rule:**
- System selected answer ko question ke correct answer se compare karta hai.
- Score total correct answers ke basis par save hota hai.
- Submission ke saath answers, score, status aur submitted time save hote hain.

### Role Wise Short Summary

| Role | Quiz Details | User Quiz Details | Public Quiz Access |
| --- | --- | --- | --- |
| Employee / Participant | No sidebar access | No access | QR/link se login, quiz attempt, submit, score view |
| L1/L2 Manager | No sidebar access unless HOD role nahi hai | No access | Participant ki tarah quiz de sakta hai agar user quiz entry bani hai |
| HOD | Create/edit/delete/import/export quiz, QR generate | User access records manage, import/export, completed history view | QR/link test kar sakta hai with valid employee code/password |

### Complete Quiz Flow
1. HOD `Quiz Details` menu me quiz create karega.
2. HOD quiz duration, status, questions, options aur correct answers set karega.
3. HOD `View QR` se QR code/public quiz link generate/share karega.
4. HOD `User Quiz Details` menu me eligible employees ke employee code aur password add/import karega.
5. Employee QR scan ya public link open karega.
6. Employee ESS Employee Code aur Password se quiz login karega.
7. Employee questions attempt karke quiz submit karega.
8. System score calculate karke submission save karega.
9. HOD `User Quiz Details` me completed quiz history aur Excel export se results dekh sakta hai.

---

## 🚀 SERVER UPDATE & DEPLOYMENT (Hinglish Guide)

Agar aapko server me code update karna hai ya koi changes deploy karne hain, toh ye steps follow karein:

### 1. Code Update Kaise Karein?
Pehle apne local changes ko git me commit aur push karein:
```bash
git add .
git commit -m "Your update message"
git push origin main
```

### 2. Server Par Deploy Kaise Karein?
Iss project mein **Kamal** deployment use ho raha hai. Naya code server par dalne ke liye ye command chalayein:
```bash
bin/kamal deploy
```
Ye command:
*   Docker image build karega.
*   Registry (Docker Hub/GHCR) par push karega.
*   Server par naya container start karega.
*   Purane container ko stop karke naya health check pass karega.

### 3. Server Logs Kaise Dekhein?
Agar server par koi error aa raha hai, toh logs dekhne ke liye:
```bash
bin/kamal logs -f
```

### 4. Rollback Kaise Karein?
Agar deploy ke baad kuch fat gaya hai aur purane version par wapas jana hai:
```bash
bin/kamal rollback
```

### 5. Rails Console On Server
Agar server par rails console chalana hai:
```bash
bin/kamal console
```

---

**End of Documentation**
