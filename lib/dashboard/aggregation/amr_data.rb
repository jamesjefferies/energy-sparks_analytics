require_relative '../half_hourly_data'
require_relative '../half_hourly_loader'

class AMRData < HalfHourlyData
  attr_reader :economic_tariff, :accounting_tariff, :grid_carbon, :carbon_emissions

  def initialize(type)
    super(type)
    @lock_updates = false
  end

  def set_economic_tariff(meter_id, fuel_type, default_energy_purchaser)
    @economic_tariff = EconomicCosts.create_costs(meter_id, self, fuel_type, default_energy_purchaser)
  end

  def set_accounting_tariff(meter_id, fuel_type, default_energy_purchaser)
    @accounting_tariff = AccountingCosts.create_costs(meter_id, self, fuel_type, default_energy_purchaser)
  end

  def set_economic_tariff_schedule(tariff)
    @economic_tariff = tariff
  end

  def set_accounting_tariff_schedule(tariff)
    @accounting_tariff = tariff
  end

  # only accessed for combined meters, where calculation is the summation of 'sub' meters
  def set_carbon_schedule(co2)
    @carbon_emissions = co2
  end

  # access point for single meters, not combined meters
  def set_carbon_emissions(meter_id_for_debug, flat_rate, grid_carbon)
    @grid_carbon = grid_carbon # needed for updates
    @carbon_emissions = CarbonEmissions.create_carbon_emissions(meter_id_for_debug, self, flat_rate, grid_carbon)
    @lock_updates = true
  end

  def add(date, one_days_data)
    throw EnergySparksUnexpectedStateException.new('Updates locked - no updates allowed') if @lock_updates
    throw EnergySparksUnexpectedStateException.new('AMR Data must not be nil') if one_days_data.nil?
    throw EnergySparksUnexpectedStateException.new("AMR Data now held as OneDayAMRReading not #{one_days_data.class.name}") unless one_days_data.is_a?(OneDayAMRReading)
    throw EnergySparksUnexpectedStateException.new("AMR Data date mismatch not #{date} v. #{one_days_data.date}") if date != one_days_data.date
    set_min_max_date(date)

    self[date] = one_days_data

    @cache_days_totals.delete(date)
  end

  def delete(date)
    super(date)
    @cache_days_totals.delete(date)
  end

  def data(date, halfhour_index)
    throw EnergySparksUnexpectedStateException.new('Deprecated call to amr_data.data()')
  end

  def days_kwh_x48(date, type = :kwh)
    kwhs = self[date].kwh_data_x48
    return kwhs if type == :kwh
    return @economic_tariff.days_cost_data_x48(date) if type == :£ || type == :economic_cost
    return @accounting_tariff.days_cost_data_x48(date) if type == :accounting_cost
    return @carbon_emissions.one_days_data_x48(date) if type == :co2
  end

  def self.fast_multiply_x48_x_x48(a, b)
    c = Array.new(48, 0.0)
    (0..47).each { |x| c[x] = a[x] * b[x] }
    c
  end

  def self.fast_add_x48_x_x48(a, b)
    c = Array.new(48, 0.0)
    (0..47).each { |x| c[x] = a[x] + b[x] }
    c
  end

  def self.fast_add_multiple_x48_x_x48(list)
    c = Array.new(48, 0.0)
    list.each do |data_x48|
      c = fast_add_x48_x_x48(c, data_x48)
    end
    c
  end

  def self.fast_multiply_x48_x_scalar(a, scalar)
    a.map { |v| v * scalar }
  end

  def set_days_kwh_x48(date, days_kwh_data_x48)
    self[date].set_days_kwh_x48(days_kwh_data_x48)
  end

  def kwh(date, halfhour_index, type = :kwh)
    return self[date].kwh_halfhour(halfhour_index) if type == :kwh
    return @economic_tariff.cost_data_halfhour(date, halfhour_index) if type == :£ || type == :economic_cost
    return @accounting_tariff.cost_data_halfhour(date, halfhour_index) if type == :accounting_cost
    return @carbon_emissions.one_days_data_x48(date)[halfhour_index] if type == :co2
  end

  def set_kwh(date, halfhour_index, kwh)
    self[date].set_kwh_halfhour(halfhour_index, kwh)
  end

  def add_to_kwh(date, halfhour_index, kwh)
    self[date].set_kwh_halfhour(halfhour_index, kwh + kwh(date, halfhour_index))
  end

  def one_day_kwh(date, type = :kwh)
    return self[date].one_day_kwh  if type == :kwh
    return @economic_tariff.one_day_total_cost(date) if type == :£ || type == :economic_cost
    return @accounting_tariff.one_day_total_cost(date) if type == :accounting_cost
    return @carbon_emissions.one_day_total(date) if type == :co2
  end

  def clone_one_days_data(date)
    self[date].deep_dup
  end
  
   # called from inherited half_hourly)data.one_day_total(date), shouldn't use generally
  def one_day_total(date, type = :kwh)
    one_day_kwh(date, type)
  end

  def total(type = :kwh)
    t = 0.0
    (start_date..end_date).each do |date|
      t += one_day_kwh(date, type)
    end
    t
  end

  def kwh_date_range(date1, date2, type = :kwh)
    return one_day_kwh(date1, type) if date1 == date2
    total_kwh = 0.0
    (date1..date2).each do |date|
      total_kwh += one_day_kwh(date, type)
    end
    total_kwh
  end

  def kwh_period(period)
    kwh_date_range(period.start_date, period.end_date)
  end

  def average_in_date_range(date1, date2, type = :kwh)
    kwh_date_range(date1, date2, type) / (date2 - date1 + 1)
  end

  def average_in_date_range_ignore_missing(date1, date2, type = :kwh)
    kwhs = []
    (date1..date2).each do |date|
      kwhs.push(one_day_kwh(date, type)) if date_exists?(date)
    end
    kwhs.empty? ? 0.0 : (kwhs.inject(:+) / kwhs.length)
  end

  def kwh_date_list(dates, type = :kwh)
    total_kwh = 0.0
    dates.each do |date|
      total_kwh += one_day_kwh(date, type)
    end
    total_kwh
  end

  def baseload_kw(date)
    statistical_baseload_kw(date)
  end

  def overnight_baseload_kw(date)
    raise EnergySparksNotEnoughDataException.new("Missing electric data (2) for #{date}") if !self.key?(date)
    baseload_kw_between_half_hour_indices(date, 41, 47)
  end

  def average_overnight_baseload_kw_date_range(date1, date2)
    overnight_baseload_kwh_date_range(date1, date2) / (date2 - date1 + 1)
  end

  def overnight_baseload_kwh_date_range(date1, date2)
    total = 0.0
    (date1..date2).each do |date|
      raise EnergySparksNotEnoughDataException.new("Missing electric data for #{date}") if !self.key?(date)
      total += overnight_baseload_kw(date)
    end
    total
  end

  def baseload_kw_between_half_hour_indices(date, hhi1, hhi2)
    total_kwh = 0.0
    count = 0
    if hhi2 > hhi1 # same day
      (hhi1..hhi2).each do |halfhour_index|
        total_kwh += kwh(date, halfhour_index)
        count += 1
      end
    else
      (hhi1..48).each do |halfhour_index| # before midnight
        total_kwh += kwh(date, halfhour_index)
        count += 1
      end
      (0..hhi2).each do |halfhour_index| # after midnight
        total_kwh += kwh(date, halfhour_index)
        count += 1
      end
    end
    total_kwh * 2.0 / count
  end

  # alternative heuristic for baseload calculation (for storage heaters)
  # find the average of the bottom 8 samples (4 hours) in a day
  def statistical_baseload_kw(date)
    days_data = days_kwh_x48(date) # 48 x 1/2 hour kWh
    sorted_kwh = days_data.clone.sort
    lowest_sorted_kwh = sorted_kwh[0..7]
    average_kwh = lowest_sorted_kwh.inject { |sum, el| sum + el }.to_f / lowest_sorted_kwh.size
    average_kwh * 2.0 # convert to kW
  end

  def statistical_peak_kw(date)
    days_data = days_kwh_x48(date) # 48 x 1/2 hour kWh
    sorted_kwh = days_data.clone.sort
    highest_sorted_kwh = sorted_kwh[45..47]
    average_kwh = highest_sorted_kwh.inject { |sum, el| sum + el }.to_f / highest_sorted_kwh.size
    average_kwh * 2.0 # convert to kW
  end

  def average_baseload_kw_date_range(date1, date2)
    baseload_kwh_date_range(date1, date2) / (date2 - date1 + 1)
  end

  def baseload_kwh_date_range(date1, date2)
    total = 0.0
    (date1..date2).each do |date|
      total += baseload_kw(date)
    end
    total
  end

  def self.create_empty_dataset(type, start_date, end_date)
    data = AMRData.new(type)
    (start_date..end_date).each do |date|
      data.add(date, OneDayAMRReading.new('Unknown', date, 'ORIG', nil, DateTime.now, Array.new(48, 0.0)))
    end
    data
  end

  # long gaps are demarked by a single LGAP meter reading - the last day of the gap
  # data held in the database doesn't store the date as part of its meta data so its
  # set here by calling this function after all meter readings are loaded
  def set_long_gap_boundary
    override_start_date = nil
    override_end_date = nil
    (start_date..end_date).each do |date|
      one_days_data = self[date]
      override_start_date = date if !one_days_data.nil? && (one_days_data.type == 'LGAP' || one_days_data.type == 'FIXS')
      override_end_date = date if !one_days_data.nil? && one_days_data.type == 'FIXE'
    end
    unless override_start_date.nil?
      logger.info "Overriding start_date of amr data from #{self.start_date} to #{override_start_date}"
      set_min_date(override_start_date)
    end
    unless override_end_date.nil?
      logger.info "Overriding end_date of amr data from #{self.end_date} to #{override_end_date}"
      set_max_date(override_end_date) unless override_end_date.nil?
    end
  end

  def summarise_bad_data
    date, one_days_data = self.first
    logger.info '=' * 80
    logger.info "Bad data for meter #{one_days_data.meter_id}"
    logger.info "Valid data between #{start_date} and #{end_date}"
    key, _value = self.first
    if key < start_date
      logger.info "Ignored data between #{key} and #{start_date} - because of long gaps"
    end
    bad_data_stats = bad_data_count
    percent_bad = 100.0
    if bad_data_count.key?('ORIG')
      percent_bad = (100.0 * (length - bad_data_count['ORIG'].length)/length).round(1)
    end
    logger.info "bad data summary: #{percent_bad}% substituted"
    bad_data_count.each do |type, dates|
      type_description = sprintf('%-60.60s', OneDayAMRReading::AMR_TYPES[type][:name])
      logger.info " #{type}: #{type_description} * #{dates.length}"
      if type != 'ORIG'
        cpdp = CompactDatePrint.new(dates)
        cpdp.log
      end
    end
  end
  
    # take one set (dd_data) of half hourly data from self
  # - avoiding performance hit of taking a copy
  # caller expected to ensure start and end dates reasonable
  def minus_self(dd_data, min_value = nil)
    sd = start_date > dd_data.start_date ? start_date : dd_data.start_date
    ed = end_date < dd_data.end_date ? end_date : dd_data.end_date
    (sd..ed).each do |date|
      (0..47).each do |halfhour_index|
        updated_kwh = kwh(date, halfhour_index) - dd_data.kwh(date, halfhour_index)
        if min_value.nil?
          set_kwh(date, halfhour_index, updated_kwh)
        else
          set_kwh(date, halfhour_index, updated_kwh > min_value ? updated_kwh : min_value)
        end
      end
    end
  end

  private
 
  # go through amr_data creating 'histogram' of type of amr_data by type (original data v. substituted)
  # returns {type} = [list of dates of that type]
  def bad_data_count
    bad_data_type_count = {}
    (start_date..end_date).each do |date|
      one_days_data = self[date]
      unless bad_data_type_count.key?(one_days_data.type)
        bad_data_type_count[one_days_data.type] = []
      end
      bad_data_type_count[one_days_data.type].push(date)
    end
    bad_data_type_count
  end
end
