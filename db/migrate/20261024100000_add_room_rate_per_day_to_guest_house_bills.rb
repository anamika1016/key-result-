# Bed rate is now entered by the guest house admin while billing instead of
# coming from Guest House Master. Nullable so bills generated earlier stay untouched.
class AddRoomRatePerDayToGuestHouseBills < ActiveRecord::Migration[8.0]
  def change
    add_column :guest_house_bookings, :room_rate_per_day, :decimal, precision: 10, scale: 2
    add_column :guest_house_booking_guests, :room_rate_per_day, :decimal, precision: 10, scale: 2
  end
end
