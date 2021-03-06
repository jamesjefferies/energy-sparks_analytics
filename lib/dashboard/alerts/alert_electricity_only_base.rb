require_relative 'alert_analysis_base.rb'

class AlertElectricityOnlyBase < AlertAnalysisBase
  def initialize(school, report_type)
    super(school, report_type)
  end

  def maximum_alert_date
    @school.aggregated_electricity_meters.amr_data.end_date
  end

  protected

  def average_baseload(date1, date2)
    amr_data = @school.aggregated_electricity_meters.amr_data
    amr_data.average_baseload_kw_date_range(date1, date2)
  end

  def annual_average_baseload_kw(asof_date)
    start_date = [asof_date - 365, @school.aggregated_electricity_meters.amr_data.start_date].max
    avg_baseload = average_baseload(start_date, asof_date)
    [avg_baseload, asof_date - start_date]
  end

  def annual_average_baseload_kwh(asof_date)
    avg_baseload, days = annual_average_baseload_kw(asof_date)
    days * 24.0 * avg_baseload
  end

  def annual_average_baseload_£(asof_date)
    kwh = annual_average_baseload_kwh(asof_date)
    kwh * blended_electricity_£_per_kwh(asof_date)
  end

  def blended_electricity_£_per_kwh(asof_date)
    rate = MeterTariffs::DEFAULT_ELECTRICITY_ECONOMIC_TARIFF
    if @school.aggregated_electricity_meters.amr_data.economic_tariff.differential_tariff?(asof_date)
      # assume its been on a differential tariff for the period
      # a slightly false assumption but it might be slow to recalculate
      # the cost for the whole period looking up potentially different tariffs
      # on different days
      rate = MeterTariffs::BLENDED_DIFFERNTIAL_RATE_APPROX
    end
    rate
  end

  def needs_gas_data?
    false
  end
end