# Chart Manager drilldown
# - given and existing chart, and drilldown, returns a drilldown chart
class ChartManager
  include Logging

  def drilldown(old_chart_name, chart_config_original, series_name, x_axis_range)
    chart_config = resolve_chart_inheritance(chart_config_original)

    if chart_config[:series_breakdown] == :baseload || 
       chart_config[:series_breakdown] == :cusum ||
       chart_config[:series_breakdown] == :hotwater ||
       chart_config[:chart1_type]      == :scatter
       # these special case may need reviewing if we decide to aggregate
       # these types of graphs by anything other than days
       # therefore create a single date datetime drilldown

       chart_config[:chart1_type] = :column
       chart_config[:series_breakdown] = :none
    else
      puts "Starting drilldown chart config:"
      ap(chart_config, limit: 20, color: { float: :red }) if ENV['AWESOMEPRINT'] == 'on'

      chart_config.delete(:inject)

      unless series_name.nil?
        new_filter = drilldown_series_name(chart_config, series_name)
        chart_config = chart_config.merge(new_filter)
      end

      chart_config[:chart1_type] = :column if chart_config[:chart1_type] == :bar
    end

    unless x_axis_range.nil?
      new_timescale_x_axis = drilldown_daterange(chart_config, x_axis_range)
      chart_config = chart_config.merge(new_timescale_x_axis)
    end

    new_chart_name = (old_chart_name.to_s + '_drilldown').to_sym

    chart_config[:name] += (series_name.nil? && x_axis_range.nil?) ? ' no drilldown' : ' drilldown'

    puts "Final drilldown chart config: #{chart_config}"
    ap(chart_config, color: { float: :red }) if ENV['AWESOMEPRINT'] == 'on'

    [new_chart_name, chart_config]
  end

  def drilldown_series_name(chart_config, series_name)
    existing_filter = chart_config.key?(:filter) ? chart_config[:filter] : {}
    existing_filter[chart_config[:series_breakdown]] = series_name
    new_filter = { filter: existing_filter }
  end

  def drilldown_daterange(chart_config, x_axis_range)
    new_x_axis = x_axis_drilldown(chart_config[:x_axis])
    if new_x_axis.nil?
      throw EnergySparksBadChartSpecification.new("Illegal drilldown requested for #{chart_config[:name]}  call drilldown_available first")
    end

    date_range_config = {
      timescale: { daterange: [x_axis_range[0], x_axis_range[1]]},
      x_axis: new_x_axis
    }
  end

  def drilldown_available(chart_config)
    !x_axis_drilldown(chart_config[:x_axis]).nil?
  end

  def x_axis_drilldown(existing_x_axis_config)
    case existing_x_axis_config
    when :year, :academicyear
      :week
    when :month, :week
      :day
    when :day
      :datetime
    when :datetime, :dayofweek, :intraday, :nodatebuckets
      nil
    else
      throw EnergySparksBadChartSpecification.new("Unhandled x_axis drilldown config #{existing_x_axis_config}")
    end
  end
end
