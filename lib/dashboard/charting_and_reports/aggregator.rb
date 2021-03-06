# aggregator - aggregates energy data in a form which can be used for generating charts
#
#     x_axis:   primarily date based: bucketing by year, month, week, day, 1/2 hour, none (implies intraday 1/2 hour but not bucketed)
#     series:   stacked representation on Y axis: [school day in/out of hours, weekend holiday] || [gas, electric, storage, PV] || hotwater [useful/non-useful]
#     y_axis:   [kwh data from meters || derived CUSUM data || baseload || hot water type] potentially converted to another proportional metric e.g. £/pupil
#     y2_axis:  temperature or degree day data - averaged or calculated, not aggregated
#
class Aggregator
  include Logging

  attr_reader :bucketed_data, :total_of_unit, :series_sums, :x_axis, :y2_axis
  attr_reader :x_axis_bucket_date_ranges, :data_labels, :x_axis_label

  def initialize(meter_collection, chart_config, show_reconciliation_values)
    @show_reconciliation_values = show_reconciliation_values
    @meter_collection = meter_collection
    @chart_config = chart_config
    @data_labels = nil
  end

  def title_summary
    if @total_of_unit.is_a?(Float) && @total_of_unit.nan?
      'NaN total'
    else
      @show_reconciliation_values ? y_axis_label(@total_of_unit) : ''
    end
  end

  def y_axis_label(value)
    YAxisScaling.unit_description(@chart_config[:yaxis_units], @chart_config[:yaxis_scaling], value)
  end

  def valid
    !@bucketed_data.nil? && !@bucketed_data.empty?
  end

  def initialise_schools_date_range
    schools = @chart_config.key?(:schools) ? load_schools(@chart_config[:schools]) : [ @meter_collection ]

    determine_multi_school_chart_date_range(schools, @chart_config)

    [@chart_config, schools]
  end

  def aggregate
    bucketed_period_data = nil

    _chart_config, schools = initialise_schools_date_range

    periods = time_periods

    sort_by = @chart_config.key?(:sort_by) ? @chart_config[:sort_by] : nil

    bucketed_period_data = run_charts_for_multiple_schools_and_time_periods(schools, periods, sort_by)

    if bucketed_period_data.length > 1 || periods.length > 1
      @bucketed_data, @bucketed_data_count = merge_multiple_charts(bucketed_period_data, schools)
    else
      @bucketed_data, @bucketed_data_count = bucketed_period_data[0]
    end

    group_by = @chart_config.key?(:group_by) ? @chart_config[:group_by] : nil

    group_chart(group_by) unless group_by.nil?

    inject_benchmarks if @chart_config[:inject] == :benchmark && !@chart_config[:inject].nil?

    remove_filtered_series if chart_has_filter && @chart_config[:series_breakdown] != :none

    create_y2_axis_data if @chart_config.key?(:y2_axis) && !@chart_config[:y2_axis].nil?

    reorganise_buckets if @chart_config[:chart1_type] == :scatter

    add_x_axis_label if @chart_config[:chart1_type] == :scatter

    # deprecated 28Feb2019
    # remove_zero_data if @chart_config[:chart1_type] == :scatter

    scale_y_axis_to_kw if @chart_config[:yaxis_units] == :kw

    reverse_series_name_order(@chart_config[:series_name_order]) if @chart_config.key?(:series_name_order) && @chart_config[:series_name_order] == :reverse

    reverse_x_axis if @chart_config.key?(:reverse_xaxis) && @chart_config[:reverse_xaxis] == true

    reformat_x_axis if @chart_config.key?(:x_axis_reformat) && !@chart_config[:x_axis_reformat].nil?

    

    aggregate_by_series

    @chart_config[:y_axis_label] = y_axis_label(nil)

    swap_NaN_for_nil if true || Object.const_defined?('Rails')
  end

  private

  def chart_has_filter
    @chart_config.key?(:filter) && !@chart_config[:filter].nil?
  end

  #=================regrouping of chart data ======================================
  # converts a flat structure e.g. :
  #     "electricity:Castle Primary School"=>[5.544020340000004, 2.9061917400000006, 0.45056400000000013],
  #     "gas:Castle Primary School"=>[1.555860000000001, 1.4714710106863198, 1.405058200146572]
  # into a hierarchical 'grouped' structure e.g.
  #   {"electricity"=>
  #     {"Castle Primary School"=>[5.544020340000004, 2.9061917400000006, 0.45056400000000013],
  #      "Paulton Junior School"=>[2.47196688, 3.4770422399999985, 2.320555619999999],
  # to better represent the grouping of clustered/grouped/stacked charts to downstream graphing/display

  def group_chart(group_by)
    @bucketed_data = regroup_bucketed_data(@bucketed_data, group_by)
    @bucketed_data_count = regroup_bucketed_data(@bucketed_data_count, group_by)
    @x_axis = regroup_xaxis(bucketed_data, @x_axis)
  end

  # rubocop:enable MethodComplexity
  def regroup_bucketed_data(bucketed_data, group_by)
    logger.info "Reorganising grouping of chart bucketed data, grouping by #{group_by.inspect}"
    logger.info "Original bucketed data: #{bucketed_data.inspect}"

    grouped_bucketed_data = Hash.new{ |h, k| h[k] = Hash.new(&h.default_proc)}
    final_hash = {}

    bucketed_data.each do |main_key, data|
      sub_keys = main_key.split(':')
      case  sub_keys.length
      when 1
        grouped_bucketed_data[sub_keys[0]] = data
      when 2
        grouped_bucketed_data[sub_keys[0]][sub_keys[1]] = data
      when 3
        grouped_bucketed_data[sub_keys[0]][sub_keys[1]][sub_keys[2]] = data
      else
        throw EnergySparksBadChartSpecification.new("Bad grouping specification too much grouping depth #{sub_keys.length}")
      end
    end
    logger.info  "Reorganised bucketed data: #{grouped_bucketed_data.inspect}"
    grouped_bucketed_data
  end

  def regroup_xaxis(bucketed_data, x_axis)
    new_x_axis = {}
    bucketed_data.each do |series_name, school_data| # electricity|gas =>  school => [array of kwh 1 per year]
      school_data.each do |school_name, _kwhs|
        new_x_axis[school_name] = x_axis
      end
    end
  end
  # rubocop:disable MethodComplexity
  #=============================================================================
  def load_schools(school_list)
    average = false
    if school_list.include?(:average)
      school_list = school_list.select{ |school| !school.is_a?(Symbol)} # remove symbols from list
      average = true
    end
    schools = AnalyticsLoadSchools.load_schools(school_list)
    if average
      config = AverageSchoolAggregator.simple_config(school_list, nil, nil, 1200, 200)
      school_averager = AverageSchoolAggregator.new(config)
      school_averager.calculate()
      schools.push(school_averager.school)
    end
    schools
  end

  def determine_multi_school_chart_date_range(schools, chart_config)
    logger.info '-' * 120
    logger.info "Determining maximum chart range for #{schools.length} schools:"
    min_date = nil
    max_date = nil

    schools.each do |school|
      series_manager = SeriesDataManager.new(school, chart_config)
      logger.info "    #{school.name} from #{series_manager.first_meter_date} to  #{series_manager.last_meter_date}"
      min_date = series_manager.first_meter_date if min_date.nil? || series_manager.first_meter_date > min_date
      max_date = series_manager.last_meter_date  if max_date.nil? || series_manager.last_meter_date  < max_date
    end

    chart_config[:min_combined_school_date] = min_date
    chart_config[:max_combined_school_date] = max_date

    description = schools.length > 1 ? 'Combined school charts' : 'School chart'
    logger.info description + " date range #{min_date} to #{max_date}"
    logger.info '-' * 120
  end

  def run_charts_for_multiple_schools_and_time_periods(schools, periods, sort_by = nil)
    saved_meter_collection = @meter_collection
    aggregations = []
    # iterate through the time periods aggregating
    schools.each do |school|
      @meter_collection = school
      periods.reverse.each do |period| # do in reverse so final iteration represents the x-axis dates
        aggregation = run_one_aggregation(@chart_config, period)
        aggregations.push(
          {
            school:       school,
            period:       period,
            aggregation:  aggregation
          }
        ) unless aggregation.nil?
      end
    end

    aggregations = sort_aggregations(aggregations, sort_by) unless sort_by.nil?

    bucketed_period_data = aggregations.map{ |aggregation_description| aggregation_description[:aggregation] }

    @meter_collection = saved_meter_collection

    bucketed_period_data
  end

  # sorting config example:      sort_by:          [ { school: :desc }, { time: :asc } ]
  # messy, could be simplified?
  def sort_aggregations(aggregations, sort_by)
    logger.info "About to sort #{aggregations.length} aggregations by #{sort_by}"
    aggregations.sort! { |x, y|
      if sort_by.length == 1
        if sort_by[0].key?(:school)
          school_compare(x, y, sort_by[0][:school])
        elsif sort_by[0].key?(:time)
          period_compare(x, y, sort_by[0][:period])
        else
          throw EnergySparksBadChartSpecification.new("Bad sort specification #{sort_by}")
        end
      else
        if sort_by[0].key?(:school)
          if x[:school].name == y[:school].name
            period_compare(x, y, sort_by[1][:period])
          else
            school_compare(x, y, sort_by[0][:school])
          end
        elsif sort_by[0].key?(:time)
          if x[:period].start_date == y[:period].start_date
            school_compare(x, y, sort_by[1][:school])
          else
            period_compare(x, y, sort_by[0][:period])
          end
        else
          throw EnergySparksBadChartSpecification.new("Bad sort specification 2 #{sort_by}")
        end
      end
    }
    aggregations
  end

  def period_compare(p1, p2, direction_definition)
    direction = direction_definition == :asc ? 1 : -1
    direction * ((p1[:period].nil? ? 0 : p1[:period].start_date) <=> (p2[:period].nil? ? 0 : p2[:period].start_date))
  end

  def school_compare(s1, s2, direction_definition)
    direction = direction_definition == :asc ? 1 : -1
    direction * (s1[:school].name <=> s2[:school].name)
  end

  def run_one_aggregation(chart_config, period)
    aggregation = nil
    chartconfig_copy = chart_config.clone
    chartconfig_copy[:timescale] = period
    begin
      aggregation = aggregate_period(chartconfig_copy)
    rescue EnergySparksMissingPeriodForSpecifiedPeriodChart => e
      logger.warn e
      logger.warn 'Warning: chart specification calls for more fixed date periods than available in AMR data(1)'
    rescue StandardError => e
      logger.error e
    end
    aggregation
  end

  def aggregate_multiple_charts_deprecated(periods)
    bucketed_period_data = []

    # iterate through the time periods aggregating
    periods.reverse.each do |period| # do in reverse so final iteration represents the x-axis dates
      chartconfig_copy = @chart_config.clone
      chartconfig_copy[:timescale] = period
      begin
        bucketed_period_data.push(aggregate_period(chartconfig_copy))
      rescue EnergySparksMissingPeriodForSpecifiedPeriodChart => e
        logger.warn e
        logger.warn 'Warning: chart specification calls for more fixed date periods than available in AMR data(2)'
      rescue StandardError => e
        logger.error e
      end
    end
    bucketed_period_data
  end

  def merge_multiple_charts(bucketed_period_data, schools)
    @bucketed_data = {}
    @bucketed_data_count = {}
    time_count, school_count = count_time_periods_and_school_names(bucketed_period_data)
    bucketed_period_data.each do |period_data|
      bucketed_data, bucketed_data_count, time_description, school_name, x_axis, x_axis_date_ranges = period_data
      time_description = time_count <= 1 ? '' : (':' + time_description)
      school_name = (schools.nil? || schools.length <= 1) ? '' : (':' + school_name)
      school_name = '' if school_count <= 1
      bucketed_data.each do |series_name, x_data|
        new_series_name = series_name.to_s + time_description + school_name
        @bucketed_data[new_series_name] = x_data
      end
      bucketed_data_count.each do |series_name, count_data|
        new_series_name = series_name.to_s + time_description + school_name
        @bucketed_data_count[new_series_name] = count_data
      end
    end
    [@bucketed_data, @bucketed_data_count]
  end

  def count_time_periods_and_school_names(bucketed_period_data)
    time_period_descriptions = {}
    school_names = {}
    bucketed_period_data.each do |period_data|
      bucketed_data, bucketed_data_count, time_description, school_name = period_data
      time_period_descriptions[time_description] = true
      school_names[school_name] = true
    end
    [time_period_descriptions.keys.length, school_names.keys.length]
  end

  def reverse_series_name_order(format)
    if format.is_a?(Symbol) && format == :reverse
      @bucketed_data = @bucketed_data.to_a.reverse.to_h
      @bucketed_data_count = @bucketed_data.to_a.reverse.to_h
    elsif format.is_a?(Array) # TODO(PH,22Jul2018): written but not tested, by be useful in future
      data = {}
      count = {}
      format.each do |series_name|
        data[series_name] = @bucketed_data[series_name]
        count[series_name] = @bucketed_data_count[series_name]
      end
      @bucketed_data = data
      @bucketed_data_count = count
    end
  end

  def reverse_x_axis
    @x_axis = @x_axis.reverse
    @x_axis_bucket_date_ranges = @x_axis_bucket_date_ranges.reverse

    @bucketed_data.each_key do |series_name|
      @bucketed_data[series_name] = @bucketed_data[series_name].reverse
      @bucketed_data_count[series_name] = @bucketed_data_count[series_name].reverse
    end

    unless @y2_axis.nil?
      @y2_axis.each_key do |series_name|
        @y2_axis[series_name] = @y2_axis[series_name].reverse
      end
    end
  end

  def reformat_x_axis
    format = @chart_config[:x_axis_reformat]
    if format.is_a?(Hash) && format.key?(:date)
      @x_axis.map! { |date| date.strftime(format[:date]) }
    else
      raise EnergySparksBadChartSpecification.new("Unexpected x axis reformat chart configuration #{format}")
    end
  end

  # charts can be specified as working over a single time period
  # or for comparison's between dates over muliple time periods
  # convert single hashes into an array with a single value
  def time_periods
    periods = []
    if !@chart_config.key?(:timescale)
      # if no time periods specified signal to series_data_manager
      # to use as much of the available data as possible i.e.
      # an unlimited timeperiod, seems to cause problems on Macs if not?
      periods.push(nil)
    elsif @chart_config[:timescale].is_a?(Array)
      periods = @chart_config[:timescale]
    else
      periods.push(@chart_config[:timescale])
    end
    periods
  end

  def aggregate_period(chart_config)
    @series_manager = SeriesDataManager.new(@meter_collection, chart_config)
    @series_names = @series_manager.series_bucket_names
    logger.info "Aggregating these series #{@series_names}"
    logger.info "aggregate_period Between #{@series_manager.first_chart_date} and #{@series_manager.last_chart_date}"

    if @series_manager.periods.empty?
      raise "Error: not enough data available to create requested chart"
    end
    @xbucketor = XBucketBase.create_bucketor(chart_config[:x_axis], @series_manager.periods)
    @xbucketor.create_x_axis
    @x_axis = @xbucketor.x_axis
    @x_axis_bucket_date_ranges = @xbucketor.x_axis_bucket_date_ranges
    logger.debug "Breaking down into #{@xbucketor.x_axis.length} X axis (date/time range) buckets"
    logger.debug "x_axis between #{@xbucketor.data_start_date} and #{@xbucketor.data_end_date} "
    bucketed_data, bucketed_data_count = create_empty_bucket_series

    # loop through date groups on the x-axis; calculate aggregate data for each series in date range

    if chart_config[:x_axis] == :intraday
      start_date = @series_manager.periods[0].start_date
      end_date = @series_manager.periods[0].end_date
      aggregate_by_halfhour(start_date, end_date, bucketed_data, bucketed_data_count)
    elsif chart_config[:x_axis] == :datetime
      start_date = @series_manager.periods[0].start_date
      end_date = @series_manager.periods[0].end_date
      aggregate_by_datetime(start_date, end_date, bucketed_data, bucketed_data_count)
    else
      aggregate_by_day(bucketed_data, bucketed_data_count)
    end
    post_process_aggregation(chart_config, bucketed_data, bucketed_data_count)
    [bucketed_data, bucketed_data_count, @xbucketor.compact_date_range_description, @meter_collection.name, @x_axis, @x_axis_bucket_date_ranges]
  end

  private

  # the analystics code treats missing and incorrectly calculated numbers as NaNs
  # unforunately the front end (Rails) prefers nil, so post process the entire
  # result set if running for rails to swap NaN for nil
  # analytics more performant in mainly using NaNs, as fewer tests required
  # e.g. total += value versus if total.nil? ? total = value : (value.nil? ? nil : total + value)
  def swap_NaN_for_nil
    return if @bucketed_data.nil?
    @bucketed_data.each do |series_name, result_data|
      @bucketed_data[series_name] = result_data.map { |x| x.nan? ? nil : x } unless result_data.is_a?(Symbol)
    end
  end

  def post_process_aggregation(chart_config, bucketed_data, bucketed_data_count)
    create_trend_lines(chart_config, bucketed_data, bucketed_data_count) if @series_manager.trendlines?
    scale_x_data(bucketed_data) if @chart_config.key?(:yaxis_scaling) && !@chart_config[:yaxis_scaling].nil? && @chart_config[:yaxis_scaling] != :none
  end

  # - process trendlines post aggregation as potentially faster, if line
  #   is represented by fewer points
  # - only works for model_type breakdowns for the moment. and only for 'daily' bucketing
  # - ignore bucketed data count as probably doesn;t apply to scatter plots with trendlines for the moment
  def create_trend_lines(chart_config, bucketed_data, _bucketed_data_count)
    if Object.const_defined?('Rails')
      add_trendlines_for_rails_all_points(bucketed_data)
    elsif false && Object.const_defined?('Rails')
      add_trendlines_for_rails_2_points(bucketed_data)
    else
      analystics_excel_trendlines(bucketed_data)
    end 
  end

  def analystics_excel_trendlines(bucketed_data)
    @series_manager.trendlines.each do |trendline_series_name|
      model_type_for_trendline = SeriesDataManager.series_name_for_trendline(trendline_series_name)
      trendline_name_with_parameters = add_regression_parameters_to_trendline_symbol(trendline_series_name, model_type_for_trendline)
      bucketed_data[trendline_name_with_parameters] = model_type_for_trendline # set model symbol
    end
  end

  def add_trendlines_for_rails_all_points(bucketed_data)
    @series_manager.trendlines.each do |trendline_series_name|
      model_type_for_trendline = SeriesDataManager.series_name_for_trendline(trendline_series_name)
      trendline_name_with_parameters = add_regression_parameters_to_trendline_symbol(trendline_series_name, model_type_for_trendline)
      bucketed_data[trendline_name_with_parameters] = Array.new(@x_axis.length, Float::NAN)
      @x_axis.each_with_index do |date, index|
        model_type = @series_manager.model_type?(date)
        if model_type == model_type_for_trendline
          bucketed_data[trendline_name_with_parameters][index] = @series_manager.predicted_amr_data_one_day(date) * trendline_scale
        end
      end
    end
  end

  def trendline_scale
    @series_manager.trendline_scale
  end

  # find 2 extreme points for each model, add interpolated regression points
  def add_trendlines_for_rails_2_points(bucketed_data)
    series_model_types = bucketed_data.keys & @series_manager.heating_model_types
    temperatures = bucketed_data['Temperature'] # problematic assumption?
    series_model_types.each do |model_type|
      model_temperatures_and_index = bucketed_data[model_type].each_with_index.map { | kwh, index| kwh.nan? ? nil : [temperatures[index], index, @x_axis[index]] }.compact
      min, max = model_temperatures_and_index.minmax_by { |temp, _index, _date| temp }
      trendline = add_regression_parameters_to_trendline_symbol(SeriesDataManager.trendline_for_series_name(model_type), model_type)
      bucketed_data[trendline] = Array.new(@x_axis.length, Float::NAN)
      bucketed_data[trendline][min[1]] = @series_manager.predicted_amr_data_one_day(min[2]) * trendline_scale
      bucketed_data[trendline][max[1]] = @series_manager.predicted_amr_data_one_day(max[2]) * trendline_scale
    end
  end

  def add_regression_parameters_to_trendline_symbol(trendline_symbol, model_type)
    model = @series_manager.model(model_type)
    parameters = model.nil? ? ' =no model' : sprintf(' =%.0f + %.1fT r2 = %.2f x %d', model.a, model.b, model.r2, model.samples)
    (trendline_symbol.to_s + parameters).to_sym
  end

  # aggregate by whole date range, the 'series_manager' deals with any spliting within a day
  # e.g. 'school day in hours' v. 'school day out of hours'
  # returns a hash of this breakdown to the kWh values
  def aggregate_by_day(bucketed_data, bucketed_data_count)
    count = 0
    if chart_has_filter && @chart_config[:filter].key?(:daytype)
      # this is slower, as it needs to loop through a day at a time
      # TODO(PH,17Jun2018) push down and optimise in series_data_manager
      @xbucketor.x_axis_bucket_date_ranges.each do |date_range|
        x_index = @xbucketor.index(date_range[0], nil)
        (date_range[0]..date_range[1]).each do |date|
          next unless match_filter_by_day(date)
          multi_day_breakdown = @series_manager.get_data([:daterange, [date, date]])
          multi_day_breakdown.each do |key, value|
            add_to_bucket(bucketed_data, bucketed_data_count, key, x_index, value)
            count += 1
          end
        end
      end
    else
      @xbucketor.x_axis_bucket_date_ranges.each do |date_range|
        x_index = @xbucketor.index(date_range[0], nil)
        multi_day_breakdown = @series_manager.get_data([:daterange, date_range])
        multi_day_breakdown.each do |key, value|
          add_to_bucket(bucketed_data, bucketed_data_count, key, x_index, value)
          count += 1
        end
      end
    end
    logger.info "aggregate_by_day:  aggregated #{count} items"
  end

  def match_filter_by_day(date)
    return true unless chart_has_filter
    match_daytype = true
    match_daytype = match_occupied_type_filter_by_day(date) if @chart_config[:filter].key?(:daytype)
    match_heating = true
    match_heating = match_filter_by_heatingdayday(date) if @chart_config[:filter].key?(:heating)
    match_model = true
    match_model = match_filter_by_model_type(date) if @chart_config[:filter].key?(:model_type)
    match_daytype && match_heating && match_model
  end

  def match_filter_by_heatingdayday(date)
    @chart_config[:filter][:heating] == @series_manager.heating_model.heating_on?(date)
  end

  def match_filter_by_model_type(date)
    model_list = @chart_config[:filter][:model_type]
    model_list = [ model_list ] if model_list.is_a?(Symbol) # convert to array if not an array
    model_list.include?(@series_manager.heating_model.model_type?(date))
  end

  def match_occupied_type_filter_by_day(date)
    filter = @chart_config[:filter][:daytype]
    holidays = @meter_collection.holidays
    case filter
    when :occupied
      !(DateTimeHelper.weekend?(date) || holidays.holiday?(date))
    when :holidays
      holidays.holiday?(date)
    when :weekends
      DateTimeHelper.weekend?(date)
    else
      true
    end
  end

  def aggregate_by_halfhour(start_date, end_date, bucketed_data, bucketed_data_count)
    # Change Line Below 22Mar2019
    if bucketed_data.length == 1 && bucketed_data.keys[0] == SeriesNames::NONE
      aggregate_by_halfhour_simple_fast(start_date, end_date, bucketed_data, bucketed_data_count)
    else
      (start_date..end_date).each do |date|
        next if !match_filter_by_day(date)
        (0..47).each do |halfhour_index|
          x_index = @xbucketor.index(nil, halfhour_index)
          multi_day_breakdown = @series_manager.get_data([:halfhour, date, halfhour_index])
          multi_day_breakdown.each do |key, value|
            add_to_bucket(bucketed_data, bucketed_data_count, key, x_index, value)
          end
        end
      end
    end
  end

  def aggregate_by_halfhour_simple_fast(start_date, end_date, bucketed_data, bucketed_data_count)
    total = Array.new(48, 0)
    count = 0
    (start_date..end_date).each do |date|
      next unless match_filter_by_day(date)
      data = @series_manager.get_one_days_data_x48(date, @series_manager.kwh_cost_or_co2)
      total = AMRData.fast_add_x48_x_x48(total, data)
      count += 1
    end
    bucketed_data[SeriesNames::NONE] = total
    bucketed_data_count[SeriesNames::NONE] = Array.new(48, count)
  end

  def aggregate_by_datetime(start_date, end_date, bucketed_data, bucketed_data_count)
    (start_date..end_date).each do |date|
      next if !match_filter_by_day(date)
      (0..47).each do |halfhour_index|
        x_index = @xbucketor.index(date, halfhour_index)
        multi_day_breakdown = @series_manager.get_data([:datetime, date, halfhour_index])
        multi_day_breakdown.each do |key, value|
          add_to_bucket(bucketed_data, bucketed_data_count, key, x_index, value)
        end
      end
    end
  end

  # this is a bit of a fudge, the data from a thermostatic scatter aggregation comes out
  # in the wrong order by default for most graphing packages, so the columns of data need
  # reorganising
  def reorganise_buckets
    dd_or_temp_key = @bucketed_data.key?(SeriesNames::DEGREEDAYS) ? SeriesNames::DEGREEDAYS : SeriesNames::TEMPERATURE
    # replace dates on x axis with degree days, but retain them for future point labelling
    x_axis = @x_axis
    @x_axis = @bucketed_data[dd_or_temp_key]
    @x_axis_bucket_date_ranges = @xbucketor.x_axis_bucket_date_ranges # may not work? PH 7Oct2018
    @bucketed_data.delete(dd_or_temp_key)

    # insert dates back in as 'silent' y2_axis
    @data_labels = x_axis
  end

  # called only for scatter charts
  def add_x_axis_label
    @x_axis_label = @bucketed_data.key?(SeriesNames::DEGREEDAYS) ? SeriesNames::DEGREEDAYS : SeriesNames::TEMPERATURE
  end

  # remove zero data - issue with filtered scatter charts, and the difficulty or representing nan (NaN) in Excel charts
  # the issue is the xbuckector doesn't know in advance the data is to be filtered based on the data
  # but the charting products can't distinguish between empty data and zero data
  def remove_zero_data
    count = 0
    indices_of_data_to_be_removed = []
    (0..@x_axis.length - 1).each do |index|
      indices_of_data_to_be_removed.push(index) if @x_axis[index] == 0
    end

    indices_of_data_to_be_removed.reverse.each do |index| # reverse order to works on self
      @x_axis.delete_at(index)
      @bucketed_data.each_key do |series_name|
        if @bucketed_data.key?(series_name) && !@bucketed_data[series_name].nil?
          @bucketed_data[series_name].delete_at(index)
          @bucketed_data_count[series_name].delete_at(index)
        else
          logger.error "Error: expecting non nil series name #{series_name}"
        end
      end
    end
    logger.info "Removing zero data: removed #{indices_of_data_to_be_removed.length} items"
  end

  # pattern matches on series_names, removing any from list which don't match
  def remove_filtered_series
    keep_key_list = []
    if !chart_has_filter
      logger.info 'No filters set'
      return
    end
    ap(@bucketed_data, limit: 20, color: { float: :red }) if ENV['AWESOMEPRINT'] == 'on'
    logger.info "Filtering start #{@bucketed_data.keys}"
    logger.debug "Filters are: #{@chart_config[:filter].inspect}" 
    if @chart_config[:series_breakdown] == :submeter
      if @chart_config[:filter].key?(:submeter)
        keep_key_list += pattern_match_list_with_list(@bucketed_data.keys, @chart_config[:filter][:submeter])
      else
        keep_key_list += @bucketed_data.keys # TODO(PH,2Jul2018) may not be generic enough?
      end
    end
    keep_key_list += pattern_match_list_with_list(@bucketed_data.keys, @chart_config[:filter][:meter]) if @chart_config[:filter].key?(:meter)
    if @chart_config.key?(:filter) && @chart_config[:filter].key?(:heating)
      filter = @chart_config[:filter][:heating] ? [SeriesNames::HEATINGDAY, SeriesNames::HEATINGDAYMODEL] : [SeriesNames::NONHEATINGDAY, SeriesNames::NONHEATINGDAYMODEL]
      keep_key_list += pattern_match_list_with_list(@bucketed_data.keys, filter)
    end
    if @chart_config.key?(:filter) && @chart_config[:filter].key?(:model_type)
      # for model filters, copy in any trendlines for those models to avoid filtering 
      model_filter = [@chart_config[:filter][:model_type]].flatten(1)
      trendline_filters = model_filter.map { |model_name| SeriesDataManager.trendline_for_series_name(model_name) }
      trendline_filters_with_parameters = pattern_match_two_symbol_lists(trendline_filters, @bucketed_data.keys)
      keep_key_list += pattern_match_list_with_list(@bucketed_data.keys, model_filter + trendline_filters_with_parameters)
    end
    if @chart_config.key?(:filter) && @chart_config[:filter].key?(:fuel)
      filtered_fuel = @chart_config[:filter][:fuel]
      keep_key_list += pattern_match_list_with_list(@bucketed_data.keys, [filtered_fuel])
    end
    if @chart_config.key?(:filter) && @chart_config[:filter].key?(:daytype)
      filtered_daytype = @chart_config[:filter][:daytype]
      keep_key_list += pattern_match_list_with_list(@bucketed_data.keys, [filtered_daytype])
    end
    keep_key_list += pattern_match_y2_axis_names

    remove_list = []
    @bucketed_data.each_key do |series_name|
      remove_list.push(series_name) unless keep_key_list.include?(series_name)
    end

    remove_list.each do |remove_series_name|
      @bucketed_data.delete(remove_series_name)
    end
    # logger.debug ap(@bucketed_data, limit: 20, color: { float: :red }) if ENV['AWESOMEPRINT'] == 'on'
    logger.debug "Filtered End #{@bucketed_data.keys}"
  end

  # e.g. [:trendline_model_xyz] with [:trendline_model_xyz_a45_b67_r282] => [:trendline_model_xyz_a45_b67_r282]
  # only check for 'included in' not proper regexp
  # gets around problem with modifying bucket symbols before filtering
  def pattern_match_two_symbol_lists(match_symbol_list, symbol_list)
    matched_pairs = match_symbol_list.product(symbol_list).select { |match, sym| sym.to_s.include?(match.to_s) }
    matched_pairs.map { |match, symbol| symbol }
  end

  def pattern_match_list_with_list(list, pattern_list)
    filtered_list = []
    pattern_list.each do |pattern|
      pattern_matched_list = list.select{ |i| i == pattern } # TODO(PH,26Jun2018) decide whether to pattern match /Lighting/ =['Lighting', 'Security Lighting']
      filtered_list += pattern_matched_list unless pattern_matched_list.empty?
    end
    filtered_list
  end

  def create_y2_axis_data
    # move bucketed data to y2 axis if configured that way
    @y2_axis = {}
    logger.debug "Moving #{@chart_config[:y2_axis]} onto Y2 axis"
    pattern_match_y2_axis_names.each do |series_name|
      @y2_axis[series_name] = @bucketed_data[series_name]
      @bucketed_data.delete(series_name)
    end
  end

  # need to deal with case where multiple merged charts and date or school suffix has been added to the end of the series name
  def pattern_match_y2_axis_names
    matched = []
    SeriesNames::Y2SERIESYMBOLTONAMEMAP.values.each do |y2_series_name|
      base_name_length = y2_series_name.length
      matched += @bucketed_data.keys.select{ |bucket_name| bucket_name[0...base_name_length] == y2_series_name }
    end
    matched
  end

  # once the aggregation process is complete, add up the aggregated data per series
  # for additional series total information which can be added to the chart legend and title
  def aggregate_by_series
    if @bucketed_data.nil?
      @total_of_unit = Float::NAN
    else
      @series_sums = {}
      @total_of_unit = 0.0
      @bucketed_data.each do |series_name, data|
        @series_sums[series_name] = data.map { |x| x.nil? || x.nan? ? 0.0 : x }.sum unless data.is_a?(Symbol)
      end
      @total_of_unit = @series_sums.values.sum
    end
  end

  def all_values_deprecated(obj)
    float_data = []
    find_all_floats(float_data, obj)
    float_data.empty? ? 0.0 : float_data.inject(:+)
  end

  # recursive search through hash/array for all float values
  def find_all_floats_deprecated(float_data, obj)
    if obj.is_a?(Hash)
      obj.each_value do |val|
        find_all_floats(float_data, val)
      end
    elsif obj.is_a?(Array)
      obj.each do |val|
        find_all_floats(float_data, val)
      end
    elsif obj.is_a?(Float)
      float_data.push(obj) unless obj.nan?
    else
      logger.info "Unexpected type #{val.class.name} to sum"
    end
  end

  def add_to_bucket(bucketed_data, bucketed_data_count, series_name, x_index, value)
    logger.warn "Unknown series name #{series_name} not in #{bucketed_data.keys}" if !bucketed_data.key?(series_name)
    logger.warn "nil value for #{series_name}" if value.nil?
    bucketed_data[series_name][x_index] += value
    bucketed_data_count[series_name][x_index] += 1 # required to calculate kW
  end

  # kw to kwh scaling is slightly painful as you need to know how many buckets
  # the scaling factor code which is used in the initial seriesdatamanager bucketing
  # already multiplies the kWh by 2, to scale from 1/2 hour to 1 hour
  def scale_y_axis_to_kw
    @bucketed_data.each do |series_name, data|
      (0..data.length - 1).each do |index|
        date_range = @xbucketor.x_axis_bucket_date_ranges[index]
        days = date_range[1] - date_range[0] + 1.0
        if @chart_config[:x_axis] == :intraday || @chart_config[:x_axis] == :datetime
          # intraday kwh data gets bucketed into 48 x 1/2 hour buckets
          # kw = kwh in bucket / dates in bucket * 2 (kWh per 1/2 hour)
          count = @bucketed_data_count[series_name][index]
          # rubocop:disable Style/ConditionalAssignment
          if count > 0
            @bucketed_data[series_name][index] = 2 * @bucketed_data[series_name][index] / count
          else
            @bucketed_data[series_name][index] = 0
          end
          # rubocop:enable Style/ConditionalAssignment
        else
          @bucketed_data[series_name][index] /= @bucketed_data_count[series_name][index]
        end
      end
    end
  end

  def inject_benchmarks
    logger.info "Injecting national, regional and exemplar bencmark data: for #{@bucketed_data.keys}"
    has_gas = @bucketed_data.key?('gas') && @bucketed_data['gas'].is_a?(Array)
    has_storage_heater = @bucketed_data.key?(SeriesNames::STORAGEHEATERS)
    has_solar_pv = @bucketed_data.key?(SeriesNames::SOLARPV)
    has_electricity = @bucketed_data.key?('electricity') && @bucketed_data['electricity'].is_a?(Array)

    if has_gas || has_electricity
      electricity_data = has_electricity ? @bucketed_data['electricity'].sum > 0.0 : false
      gas_only = has_gas && !has_electricity # for gas only schools don;t display electric benchmark, but not vice versa (electric heated schools)
      @x_axis.push('National Average')
      @bucketed_data['electricity'].push(benchmark_electricity_usage_in_units) if electricity_data
      @bucketed_data['gas'].push(benchmark_gas_usage_in_units)
      @bucketed_data[SeriesNames::STORAGEHEATERS].push(0.0) if has_storage_heater
      @bucketed_data[SeriesNames::SOLARPV].push(0.0) if has_solar_pv

      @x_axis.push('Regional Average')
      @bucketed_data['electricity'].push(benchmark_electricity_usage_in_units) if electricity_data
      @bucketed_data['gas'].push(benchmark_gas_usage_in_units * 0.9)
      @bucketed_data[SeriesNames::STORAGEHEATERS].push(0.0) if has_storage_heater
      @bucketed_data[SeriesNames::SOLARPV].push(0.0) if has_solar_pv

      @x_axis.push('Exemplar School')
      @bucketed_data['electricity'].push(exemplar_electricity_usage_in_units) if electricity_data
      @bucketed_data['gas'].push(exemplar_gas_usage_in_units * 0.9)
      @bucketed_data[SeriesNames::STORAGEHEATERS].push(0.0) if has_storage_heater
      @bucketed_data[SeriesNames::SOLARPV].push(0.0) if has_solar_pv
    else
      @x_axis.push('National Average')
      @bucketed_data['electricity']['National Average'] = benchmark_electricity_usage_in_units
      @bucketed_data['gas']['National Average'] = benchmark_gas_usage_in_units

      @x_axis.push('Regional Average')
      @bucketed_data['electricity']['Regional Average'] = benchmark_electricity_usage_in_units
      @bucketed_data['gas']['Regional Average'] = benchmark_gas_usage_in_units * 0.9

      @x_axis.push('Exemplar School')
      @bucketed_data['electricity']['Exemplar School'] = exemplar_electricity_usage_in_units
      @bucketed_data['gas']['Exemplar School'] = exemplar_gas_usage_in_units * 0.9
    end
  end

  # performs scaling to 200, 1000 pupils or primary/secondary default sized floor areas
  private def scale_x_data(bucketed_data)
    # exclude y2_axis values e.g. temperature, degree days
    x_data_keys = bucketed_data.select { |series_name, data| !SeriesNames::Y2SERIESYMBOLTONAMEMAP.values.include?(series_name) }
    scale_factor = YAxisScaling.new.scaling_factor(@chart_configuration[:yaxis_scaling], @meter_collection)
    info = "Scaling the following series #{x_data_keys} by a factor of #{scale_factor} for y axis scaling #{@chart_configuration[:yaxis_scaling]}"
    puts info
    log.info info
    x_data_keys.each do |data_series_name|
      bucketed_data[data_series_name].each_with_index do |value, index|
        bucketed_data[data_series_name][index] = value * scale_factor
      end
    end
  end

  def scale_benchmarks(benchmark_usage_kwh, fuel_type)
    y_scaling = YAxisScaling.new
    y_scaling.scale_from_kwh(benchmark_usage_kwh, @chart_config[:yaxis_units], @chart_config[:yaxis_scaling], fuel_type, @meter_collection)
  end

  def exemplar_electricity_usage_in_units
    scale_benchmarks(BenchmarkMetrics::EXEMPLAR_ELECTRICITY_USAGE_PER_PUPIL * @meter_collection.number_of_pupils, :electricity)
  end

  def exemplar_gas_usage_in_units
    scale_benchmarks(BenchmarkMetrics::EXEMPLAR_GAS_USAGE_PER_M2 * @meter_collection.floor_area, :gas)
  end

  def benchmark_electricity_usage_in_units
    scale_benchmarks(BenchmarkMetrics::BENCHMARK_ELECTRICITY_USAGE_PER_PUPIL * @meter_collection.number_of_pupils, :electricity)
  end

  def benchmark_gas_usage_in_units
    scale_benchmarks(BenchmarkMetrics::BENCHMARK_GAS_USAGE_PER_M2 * @meter_collection.floor_area, :gas)
  end

  def create_empty_bucket_series
    logger.debug "Creating empty data buckets #{@series_names} x #{@x_axis.length}"
    bucketed_data = {}
    bucketed_data_count = {}
    @series_names.each do |series_name|
      bucketed_data[series_name] = Array.new(@x_axis.length, 0.0)
      bucketed_data_count[series_name] = Array.new(@x_axis.length, 0)
    end
    [bucketed_data, bucketed_data_count]
  end
end
