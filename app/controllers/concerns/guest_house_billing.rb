# Shared billing helpers for guest house checkout and individual occupant bills.
# Rates are entered by the guest house admin while billing; Guest House Master
# rates are only used as a fallback for forms submitted without a rate.
module GuestHouseBilling
  extend ActiveSupport::Concern

  class InvalidRate < StandardError; end

  private

  # Returns a non-negative BigDecimal, nil when blank, or raises InvalidRate.
  def parse_billing_rate(value, label)
    text = value.to_s.strip
    return nil if text.blank?

    rate = BigDecimal(text)
    raise InvalidRate, "#{label} cannot be negative." if rate.negative?

    rate.round(2)
  rescue ArgumentError
    raise InvalidRate, "#{label} must be a number."
  end

  # Services the admin ticked, each with the quantity and rate the admin entered.
  # Returns [total_amount, detail_lines].
  def selected_facility_charges(selected, guest_house_id)
    facility_ids = Array(selected[:facility_ids]).reject(&:blank?)
    return [ 0.to_d, [] ] if facility_ids.blank?

    quantities = selected[:facility_quantities] || {}
    rates = selected[:facility_rates] || {}
    facilities = GuestHouseFacility.active.where(id: facility_ids, guest_house_id: guest_house_id).index_by { |facility| facility.id.to_s }

    lines = []
    total = facility_ids.sum(0.to_d) do |facility_id|
      facility = facilities[facility_id.to_s]
      next 0.to_d if facility.blank?

      quantity = [ quantities[facility_id.to_s].to_i, 1 ].max
      rate = parse_billing_rate(rates[facility_id.to_s], "#{facility.name} rate")
      raise InvalidRate, "Enter the rate for #{facility.name}." if rate.nil? && rates.key?(facility_id.to_s)

      rate ||= facility.rate.to_d
      amount = rate * quantity
      lines << "#{facility.name} x #{quantity} @ Rs. #{format('%.2f', rate)} = Rs. #{format('%.2f', amount)}"
      amount
    end

    [ total, lines ]
  end
end
