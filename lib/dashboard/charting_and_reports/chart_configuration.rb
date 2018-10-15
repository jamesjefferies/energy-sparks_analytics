# Chart Manager - aggregates data for graphing - producing 'Charts'
#                - which include basic data for graphing, comments, alerts
class ChartManager
  STANDARD_CHART_CONFIGURATION = {
    #
    # chart confif parameters:
    # name:               As appears in title of chart; passed through back to output with addition data e.g. total kWh
    # series_breakdown:   :fuel || :daytype || :heatingon - so fuel auto splits into [gas, electricity]
    #                      daytype into holidays, weekends, schools in and out of hours
    #                      heatingon - heating and non heating days
    #                     ultimately the plan is to support a list of breaddowns
    # chart1_type:        bar || column || pie || scatter - gets passed through back to output
    # chart1_subtype:     generally not present, if present 'stacked' is its most common value
    # x_axis:             grouping of data on xaxis: :intraday :day :week :dayofweek :month :year :academicyear
    # timescale:          period overwhich data aggregated - assumes tie covering all available data if missing
    # yaxis_units:        :£ etc. TODO PG,23May2018) - complete documentation
    # data_types:         an array e.g. [:metereddata, :predictedheat] - assumes :metereddata if not present
    #
    benchmark:  {
      name:             'Annual Electricity and Gas Consumption Comparison with other schools in your region',
      chart1_type:      :bar,
      chart1_subtype:   :stacked,
      meter_definition: :all,
      x_axis:           :year,
      series_breakdown: :fuel,
      yaxis_units:      :£,
      yaxis_scaling:    :none,
      inject:           :benchmark
    },
    benchmark_electric:  {
      name:             'Benchmark Comparison (Annual Electricity Consumption)',
      chart1_type:      :bar,
      chart1_subtype:   :stacked,
      meter_definition: :all,
      x_axis:           :year,
      series_breakdown: :fuel,
      yaxis_units:      :£,
      yaxis_scaling:    :none,
      inject:           :benchmark
      # timescale:        :year
    },
    gas_longterm_trend: {
      name:             'Gas: long term trends',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      meter_definition: :allheat,
      x_axis:           :year,
      series_breakdown: :daytype,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none,
      y2_axis:          :degreedays,
      reverse_xaxis:    true
    },
    electricity_longterm_trend: {
      name:             'Electricity: long term trends',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      meter_definition: :allelectricity,
      x_axis:           :year,
      series_breakdown: :daytype,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none,
      reverse_xaxis:    true
    },
    daytype_breakdown_gas: {
      name:             'Breakdown by type of day/time: Gas',
      chart1_type:      :pie,
      meter_definition: :allheat,
      x_axis:           :nodatebuckets,
      series_breakdown: :daytype,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none,
      timescale:        :year
    },
    daytype_breakdown_electricity: {
      name:             'Breakdown by type of day/time: Electricity',
      chart1_type:      :pie,
      meter_definition: :allelectricity,
      x_axis:           :nodatebuckets,
      series_breakdown: :daytype,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none,
      timescale:        :year
    },
    group_by_week_electricity: {
      name:             'By Week: Electricity',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      meter_definition: :allelectricity,
      x_axis:           :week,
      series_breakdown: :daytype,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none,
      timescale:        :year
    },
    group_by_week_electricity_test_range: {
      inherits_from:    :group_by_week_electricity,
      name:             'By Day: Electricity Range Test',
      timescale:        {year: -3..-1}
    },
    electricity_by_day:  {
      inherits_from:    :group_by_week_electricity,
      name:             'By Day: Electricity',
      x_axis:           :day,
      timescale:        :week
    },
    electricity_by_datetime:  {
      inherits_from:    :group_by_week_electricity,
      name:             'By Time: Electricity',
      x_axis:           :datetime,
      timescale:        :day
    },
    electricity_by_datetime_line_kw:  {
      inherits_from:    :electricity_by_datetime,
      chart1_type:      :line,
      series_breakdown: :none,
      yaxis_units:      :kw
    },
    group_by_week_electricity_school_comparison: {
      inherits_from:    :group_by_week_electricity,
      name:             'By Week: Electricity - School Comparison',
      series_breakdown: :none,
      chart1_subtype:   nil,
      yaxis_scaling:    :per_floor_area,
      schools: [
        { urn: 109089 },  # Paulton Junior
        { urn: 109328 },  # St Marks
        { urn: 109005 },  # St Johns
        { urn: 109081 }   # Castle
      ]
    },
    group_by_week_electricity_school_comparison_line: {
      inherits_from:    :group_by_week_electricity_school_comparison,
      chart1_type:      :line
    },
    electricity_longterm_trend_school_comparison: {
      inherits_from:    :electricity_longterm_trend,
      name:             'Electricity: long term trends school comparison',
      series_breakdown: :none,
      chart1_subtype:   nil,
      yaxis_scaling:    :per_floor_area,
      schools: [
        { urn: 109089 },  # Paulton Junior
        { urn: 109328 },  # St Marks
        { urn: 109005 },  # St Johns
        { urn: 109081 }   # Castle
      ]
    },
    intraday_line_school_days_school_comparison: {
      inherits_from:    :intraday_line_school_days,
      name:             'Electricity: comparison of last 2 years and school comparison',
      series_breakdown: :none,
      yaxis_scaling:    :per_200_pupils,
      schools: [
        { urn: 109089 },  # Paulton Junior
        { urn: 109328 },  # St Marks
        { urn: 109005 },  # St Johns
        { urn: 109081 }   # Castle
      ]
    },
    group_by_week_electricity_unlimited: {
      name:             'By Week: Electricity (multi-year)',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      zoomable:         true,
      meter_definition: :allelectricity,
      x_axis:           :week,
      series_breakdown: :daytype,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none
    },
    group_by_week_electricity_unlimited_meter_filter_debug: {
      name:             'By Week: Electricity (Meter Breakdown)',
      meter_definition: :allelectricity,
      inherits_from:    :group_by_week_gas_unlimited_meter_filter_debug,
      series_breakdown: :meter
    },
    group_by_week_gas: {
      name:             'By Week: Gas',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      meter_definition: :allheat,
      x_axis:           :week,
      series_breakdown: :daytype,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none,
      y2_axis:          :degreedays,
      timescale:        :year
    },
    group_by_week_gas_unlimited: {
      name:             'By Week: Gas (multi-year)',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      zoomable:         true,
      meter_definition: :allheat,
      x_axis:           :week,
      series_breakdown: :daytype,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none,
      y2_axis:          :degreedays
    },
    group_by_week_gas_unlimited_meter_filter_debug: {
      name:             'By Week: Gas (Meter Breakdown)',
      inherits_from:    :group_by_week_gas_unlimited,
      series_breakdown: :meter
      # filter:            { meter: [ 'Electrical Heating' ] } 
    },
    group_by_week_gas_kw: {
      name:             'By Week: Gas',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      meter_definition: :allheat,
      x_axis:           :week,
      series_breakdown: :daytype,
      yaxis_units:      :kw,
      yaxis_scaling:    :none,
      y2_axis:          :degreedays
    },
    group_by_week_gas_kwh: {
      name:             'By Week: Gas',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      meter_definition: :allheat,
      x_axis:           :week,
      series_breakdown: :daytype,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none,
      y2_axis:          :degreedays
    },
    group_by_week_gas_kwh_pupil: {
      name:             'By Week: Gas',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      meter_definition: :allheat,
      x_axis:           :week,
      series_breakdown: :daytype,
      yaxis_units:      :kwh,
      yaxis_scaling:    :per_pupil,
      y2_axis:          :degreedays
    },
    group_by_week_gas_co2_floor_area: {
      name:             'By Week: Gas',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      meter_definition: :allheat,
      x_axis:           :week,
      series_breakdown: :daytype,
      yaxis_units:      :co2,
      yaxis_scaling:    :per_floor_area,
      y2_axis:          :degreedays
    },
    group_by_week_gas_library_books: {
      name:             'By Week: Gas',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      meter_definition: :allheat,
      x_axis:           :week,
      series_breakdown: :daytype,
      yaxis_units:      :library_books,
      yaxis_scaling:    :none,
      y2_axis:          :degreedays
    },
    gas_latest_years:  {
      name:             'Gas Use Over Last Few Years (to date)',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      series_breakdown: :daytype,
      x_axis:           :year,
      meter_definition: :allheat,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none,
      y2_axis:          :temperature
    },
    gas_latest_academic_years:  {
      name:             'Gas Use Over Last Few Academic Years',
      chart1_type:      :bar,
      chart1_subtype:   :stacked,
      series_breakdown: :daytype,
      x_axis:           :academicyear,
      meter_definition: :allheat,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none
    },
    gas_by_day_of_week:  {
      name:             'Gas Use By Day of the Week (this year)',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      series_breakdown: :daytype,
      x_axis:           :dayofweek,
      timescale:        :year,
      meter_definition: :allheat,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none
    },
    electricity_by_day_of_week:  {
      name:             'Electricity Use By Day of the Week (this year)',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      series_breakdown: :daytype,
      x_axis:           :dayofweek,
      timescale:        :year,
      meter_definition: :allelectricity,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none
    },
    electricity_by_month_acyear_0_1:  {
      name:             'Electricity Use By Month (previous 2 academic years)',
      chart1_type:      :column,
      # chart1_subtype:   :stacked,
      series_breakdown: :none,
      x_axis:           :month,
      timescale:        [{ academicyear: 0 }, { academicyear: -1 }],
      meter_definition: :allelectricity,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none
    },
    electricity_by_month_year_0_1:  {
      name:             'Electricity Use By Month (last 2 years)',
      chart1_type:      :column,
      # chart1_subtype:   :stacked,
      series_breakdown: :none,
      x_axis:           :month,
      timescale:        [{ year: 0 }, { year: -1 }],
      meter_definition: :allelectricity,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none
    },
    gas_heating_season_intraday: {
      name:             'Intraday Gas Consumption (during heating season)',
      chart1_type:      :column,
      meter_definition: :allheat,
      timescale:        :year,
      filter:            { daytype: :occupied, heating: true },
      series_breakdown: :none,
      x_axis:           :intraday,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none
    },
    thermostatic: {
      name:             'Thermostatic (Heating Season, School Day)',
      chart1_type:      :scatter,
      meter_definition: :allheat,
      timescale:        :year,
      filter:            { daytype: :occupied, heating: true },
      series_breakdown: %i[heating heatingmodeltrendlines degreedays],
      x_axis:           :day,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none
    },
    thermostatic_non_heating: {
      name:             'Thermostatic (Non Heating Season, School Day)',
      chart1_type:      :scatter,
      meter_definition: :allheat,
      timescale:        :year,
      filter:            { daytype: :occupied, heating: false },
      series_breakdown: %i[heating heatingmodeltrendlines degreedays],
      x_axis:           :day,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none
    },
    cusum: {
      name:             'CUSUM',
      chart1_type:      :line,
      meter_definition: :allheat,
      series_breakdown: :cusum,
      x_axis:           :day,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none
    },
    baseload: {
      name:             'Baseload kW',
      chart1_type:      :line,
      series_breakdown: :baseload,
      meter_definition: :allelectricity,
      x_axis:           :day,
      yaxis_units:      :kw,
      yaxis_scaling:    :none
    },
    baseload_lastyear: {
      name:             'Baseload kW - last year',
      chart1_type:      :line,
      series_breakdown: :baseload,
      meter_definition: :allelectricity,
      timescale:        :year,
      x_axis:           :day,
      yaxis_units:      :kw,
      yaxis_scaling:    :none
    },
    intraday_line_school_days:  {
      name:             'Intraday (school days) - comparison of last 2 years',
      chart1_type:      :line,
      series_breakdown: :none,
      timescale:        [{ year: 0 }, { year: -1 }],
      x_axis:           :intraday,
      meter_definition: :allelectricity,
      filter:            { daytype: :occupied },
      yaxis_units:      :kw,
      yaxis_scaling:    :none
    },
    intraday_line_school_days_last5weeks:  {
      name:             'Intraday (Last 5 weeks comparison - school day)',
      chart1_type:      :line,
      series_breakdown: :none,
      timescale:        [{ schoolweek: 0 }, { schoolweek: -1 }, { schoolweek: -2 }, { schoolweek: -3 }, { schoolweek: -4 }],
      x_axis:           :intraday,
      meter_definition: :allelectricity,
      filter:            { daytype: :occupied },
      yaxis_units:      :kw,
      yaxis_scaling:    :none
    },
    intraday_line_school_days_6months:  {
      name:             'Intraday (Comparison 6 months apart)',
      chart1_type:      :line,
      series_breakdown: :none,
      timescale:        [{ schoolweek: 0 }, { schoolweek: -20 }],
      x_axis:           :intraday,
      meter_definition: :allelectricity,
      filter:            { daytype: :occupied },
      yaxis_units:      :kw,
      yaxis_scaling:    :none
    },
    intraday_line_school_days_6months_test_delete:  {
      name:             'Intraday (Comparison 6 months apart)',
      chart1_type:      :line,
      series_breakdown: :none,
      timescale:        [{ schoolweek: 0 }, { schoolweek: -20 }],
      x_axis:           :intraday,
      meter_definition: :allelectricity,
      filter:            { daytype: :occupied },
      yaxis_units:      :kw,
      yaxis_scaling:    :none
    },
    intraday_line_school_last7days:  {
      name:             'Intraday (last 7 days)',
      chart1_type:      :line,
      series_breakdown: :none,
      timescale:        [{ day: 0 }, { day: -1 }, { day: -2 }, { day: -3 }, { day: -4 }, { day: -5 }, { day: -6 }],
      x_axis:           :intraday,
      meter_definition: :allelectricity,
      yaxis_units:      :kw,
      yaxis_scaling:    :none
    },
    intraday_line_holidays:  {
      name:             'Intraday (holidays)',
      chart1_type:      :line,
      series_breakdown: :none,
      timescale:        [{ year: 0 }, { year: -1 }],
      x_axis:           :intraday,
      meter_definition: :allelectricity,
      filter:           { daytype: :holidays },
      yaxis_units:      :kw,
      yaxis_scaling:    :none
    },
    intraday_line_weekends:  {
      name:             'Intraday (weekends)',
      chart1_type:      :line,
      series_breakdown: :none,
      timescale:        [{ year: 0 }, { year: -1 }],
      x_axis:           :intraday,
      meter_definition: :allelectricity,
      filter:           { daytype: :weekends },
      yaxis_units:      :kw,
      yaxis_scaling:    :none
    },
    group_by_week_electricity_dd: {
      name:             'By Week: Electricity',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      meter_definition: :allelectricity,
      x_axis:           :week,
      series_breakdown: :daytype,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none,
      y2_axis:          :degreedays,
      timescale:        :year
    },
    group_by_week_electricity_simulator_appliance: {
      name:             'By Week: Electricity Simulator',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      meter_definition: :electricity_simulator,
      x_axis:           :week,
      series_breakdown: :submeter,
      filter:            { submeter: [ 'Flood Lighting'] },
      yaxis_units:      :kwh,
      yaxis_scaling:    :none,
      timescale:        :year
    },
    group_by_week_electricity_simulator_ict: {
      name:             'By Week: Electricity Simulator (ICT Servers, Desktops, Laptops)',
      inherits_from:    :group_by_week_electricity_simulator_appliance,
      filter:            { submeter: [ 'Laptops', 'Desktops', 'Servers' ] },
      series_name_order: :reverse
    },

    group_by_week_electricity_simulator_electrical_heating: {
      name:             'By Week: Electricity Simulator (Heating using Electricity)',
      inherits_from:    :group_by_week_gas,
      meter_definition: :electricity_simulator,
      series_breakdown: :submeter,
      filter:            { submeter: [ 'Electrical Heating' ] }
    },
    intraday_electricity_simulator_actual_for_comparison: {
      name:             'Annual: School Day by Time of Day (Actual)',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      series_breakdown: :none,
      timescale:        :year,
      x_axis:           :intraday,
      meter_definition: :allelectricity,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none
    },
    intraday_electricity_simulator_simulator_for_comparison: {
      name:             'Annual: School Day by Time of Day (Simulator)',
      inherits_from:    :intraday_electricity_simulator_actual_for_comparison,
      meter_definition: :electricity_simulator
    },
    intraday_electricity_simulator_ict: {
      name:             'Annual: School Day by Time of Day: Electricity Simulator (ICT Servers, Desktops, Laptops)',
      inherits_from:    :intraday_electricity_simulator_actual_for_comparison,
      series_breakdown: :submeter,
      meter_definition: :electricity_simulator,
      filter:            { daytype: :occupied, submeter: [ 'Laptops', 'Desktops', 'Servers' ] },
      series_name_order: :reverse
    },
    electricity_by_day_of_week_simulator_ict: {
      name:             'Annual: Usage by Day of Week: Electricity Simulator (ICT Servers, Desktops, Laptops)',
      inherits_from:    :electricity_by_day_of_week_simulator,
      series_breakdown: :submeter,
      meter_definition: :electricity_simulator,
      filter:            { submeter: [ 'Laptops', 'Desktops', 'Servers' ] },
      series_name_order: :reverse
    },

    #==============================SIMULATOR LIGHTING DETAIL==============================
    group_by_week_electricity_simulator_lighting: {
      name:             'By Week: Electricity Simulator (Lighting)',
      inherits_from:    :group_by_week_electricity_simulator_appliance,
      filter:            { submeter: [ 'Lighting' ] }
    },
    intraday_electricity_simulator_lighting_kwh: {
      name:             'Annual: School Day by Time of Day: Electricity Simulator (Lighting)',
      inherits_from:    :intraday_electricity_simulator_ict,
      filter:            { daytype: :occupied, submeter: ['Lighting'] }
    },
    intraday_electricity_simulator_lighting_kw: {
      name:             'Annual: School Day by Time of Day: Electricity Simulator (Lighting)',
      inherits_from:    :intraday_electricity_simulator_lighting_kwh,
      yaxis_units:      :kw,
      filter:            { daytype: :occupied, submeter: ['Lighting'] }
    },
    #==============================SIMUALATOR BOILER PUMP DETAIL==============================
    group_by_week_electricity_simulator_boiler_pump: {
      name:             'By Week: Electricity Simulator (Boiler Pumps)',
      inherits_from:    :group_by_week_electricity_simulator_appliance,
      filter:            { submeter: ['Boiler Pumps'] }
    },
    intraday_electricity_simulator_boiler_pump_kwh: {
      name:             'Annual: School Day by Time of Day: Electricity Simulator (Boiler Pumps)',
      inherits_from:    :intraday_electricity_simulator_ict,
      filter:            { submeter: ['Boiler Pumps'] }
    },
    #==============================SIMUALATOR SECURITY LIGHTING DETAIL==============================
    group_by_week_electricity_simulator_security_lighting: {
      name:             'By Week: Electricity Simulator (Security Lighting)',
      inherits_from:    :group_by_week_electricity_simulator_appliance,
      filter:            { submeter: ['Security Lighting'] }
    },
    intraday_electricity_simulator_security_lighting_kwh: {
      name:             'Annual: School Day by Time of Day: Electricity Simulator (Security Lighting)',
      inherits_from:    :intraday_electricity_simulator_ict,
      filter:            { submeter: ['Security Lighting'] }
    },
    #==============================AIR CONDITIONING================================================
    group_by_week_electricity_air_conditioning: {
      name:             'By Week: Electricity Simulator (Air Conditioning)',
      inherits_from:    :group_by_week_electricity_simulator_appliance,
      filter:            { submeter: ['Air Conditioning'] },
      y2_axis:          :temperature
    },
    intraday_electricity_simulator_air_conditioning_kwh: {
      name:             'Annual: School Day by Time of Day: Electricity Simulator (Air Conditioning)',
      inherits_from:    :intraday_electricity_simulator_ict,
      filter:            { submeter: [ 'Air Conditioning' ] }
    },
    #==============================FLOOD LIGHTING================================================
    group_by_week_electricity_flood_lighting: {
      name:             'By Week: Electricity Simulator (Flood Lighting)',
      inherits_from:    :group_by_week_electricity_simulator_appliance,
      filter:            { submeter: ['Flood Lighting'] },
    },
    intraday_electricity_simulator_flood_lighting_kwh: {
      name:             'Annual: School Day by Time of Day: Electricity Simulator (Flood Lighting)',
      inherits_from:    :intraday_electricity_simulator_ict,
      filter:            { submeter: ['Flood Lighting'] }
    },
    #==============================KITCHEN================================================
    group_by_week_electricity_kitchen: {
      name:             'By Week: Electricity Simulator (Kitchen)',
      inherits_from:    :group_by_week_electricity_simulator_appliance,
      filter:            { submeter: ['Kitchen'] },
    },
    intraday_electricity_simulator_kitchen_kwh: {
      name:             'Annual: School Day by Time of Day: Electricity Simulator (Kitchen)',
      inherits_from:    :intraday_electricity_simulator_ict,
      filter:            { submeter: ['Kitchen'] }
    },
    #==============================SOLAR PV================================================
    group_by_week_electricity_simulator_solar_pv: {
      name:             'By Month: Electricity Simulator (Solar PV)',
      inherits_from:    :group_by_week_electricity_simulator_appliance,
      x_axis:           :month,
      filter:            { submeter: ['Solar PV Internal Consumption', 'Solar PV Export'] }
    },
    intraday_electricity_simulator_solar_pv_kwh: {
      name:             'Annual: School Day by Time of Day: Electricity Simulator (Solar PV)',
      inherits_from:    :intraday_electricity_simulator_ict,
      filter:            { submeter: ['Solar PV Internal Consumption', 'Solar PV Export'] }
    },

    # MAIN SIMULATOR DASHBOARD CHARTS
    electricity_simulator_pie: {
      name:             'Electricity Simulator (Simulated Usage Breakdown Over the Last Year)',
      chart1_type:      :pie,
      meter_definition: :electricity_simulator,
      x_axis:           :nodatebuckets,
      series_breakdown: :submeter,
      yaxis_units:      :kwh,
      yaxis_scaling:    :none,
      timescale:        :year
    },
    electricity_simulator_pie_detail_page: {
      inherits_from:    :electricity_simulator_pie,
    },

    group_by_week_electricity_actual_for_simulator_comparison: {
      name:             'By Week: Electricity (Actual Usage)',
      inherits_from:    :group_by_week_electricity
    },
    group_by_week_electricity_simulator: {
      name:             'By Week: Electricity (Simulator)',
      inherits_from:    :group_by_week_electricity_actual_for_simulator_comparison,
      meter_definition: :electricity_simulator
    },
    electricity_by_day_of_week_actual_for_simulator_comparison:  {
      name:             'Electricity Use By Day of the Week (Actual Usage over last year)',
      inherits_from:    :electricity_by_day_of_week,
    },
    electricity_by_day_of_week_simulator:  {
      name:             'Electricity Use By Day of the Week (Simulator Usage over last year)',
      inherits_from:    :electricity_by_day_of_week,
      meter_definition: :electricity_simulator
    },

    intraday_line_school_days_6months_simulator:  {
      name:             'Intraday (Comparison 6 months apart) Simulator',
      chart1_type:      :line,
      series_breakdown: :none,
      timescale:        [{ schoolweek: 0 }, { schoolweek: -20 }],
      x_axis:           :intraday,
      meter_definition: :electricity_simulator,
      filter:            { daytype: :occupied },
      yaxis_units:      :kw,
      yaxis_scaling:    :none
    },
    intraday_line_school_days_6months_simulator_submeters:  {
      name:             'Intraday (Comparison 6 months apart) Simulator',
      chart1_type:      :line,
      series_breakdown: :submeter,
      timescale:        [{ schoolweek: 0 }, { schoolweek: -20 }],
      x_axis:           :intraday,
      meter_definition: :electricity_simulator,
      filter:            { daytype: :occupied },
      yaxis_units:      :kw,
      yaxis_scaling:    :none
    },
    frost_1:  {
      name:             'Frost Protection Example Sunday 1',
      chart1_type:      :column,
      series_breakdown: :none,
      timescale:        [{ frostday_3: 0 }], # 1 day either side of frosty day i.e. 3 days
      x_axis:           :datetime,
      meter_definition: :allheat,
      yaxis_units:      :kw,
      yaxis_scaling:    :none,
      y2_axis:          :temperature
    },
    frost_2:  {
      name:             'Frost Protection Example Sunday 2',
      chart1_type:      :column,
      series_breakdown: :none,
      timescale:        [{ frostday_3: -1 }], # skip -1 for moment, as 12-2-2017 has no gas data at most schools TODO(PH,27Jun2017) - fix gas data algorithm
      x_axis:           :datetime,
      meter_definition: :allheat,
      yaxis_units:      :kw,
      yaxis_scaling:    :none,
      y2_axis:          :temperature
    },
    frost_3:  {
      name:             'Frost Protection Example Sunday 3',
      chart1_type:      :column,
      series_breakdown: :none,
      timescale:        [{ frostday_3: -2 }],
      x_axis:           :datetime,
      meter_definition: :allheat,
      yaxis_units:      :kw,
      yaxis_scaling:    :none,
      y2_axis:          :temperature
    },
    thermostatic_control_large_diurnal_range_1:  {
      name:             'Thermostatic Control Large Diurnal Range Assessment 1',
      chart1_type:      :column,
      series_breakdown: :none,
      timescale:        [{ diurnal: 0 }],
      x_axis:           :datetime,
      meter_definition: :allheat,
      yaxis_units:      :kw,
      yaxis_scaling:    :none,
      y2_axis:          :temperature
    },
    thermostatic_control_large_diurnal_range_2:  {
      name:             'Thermostatic Control Large Diurnal Range Assessment 2',
      chart1_type:      :column,
      series_breakdown: :none,
      timescale:        [{ diurnal: -1 }],
      x_axis:           :datetime,
      meter_definition: :allheat,
      yaxis_units:      :kw,
      yaxis_scaling:    :none,
      y2_axis:          :temperature
    },
    thermostatic_control_large_diurnal_range_3:  {
      name:             'Thermostatic Control Large Diurnal Range Assessment 3',
      chart1_type:      :column,
      series_breakdown: :none,
      timescale:        [{ diurnal: -2 }],
      x_axis:           :datetime,
      meter_definition: :allheat,
      yaxis_units:      :kw,
      yaxis_scaling:    :none,
      y2_axis:          :temperature
    },
    thermostatic_control_medium_diurnal_range:  {
      name:             'Thermostatic Control Medium Diurnal Range Assessment 3',
      chart1_type:      :column,
      series_breakdown: :none,
      timescale:        [{ diurnal: -20 }],
      x_axis:           :datetime,
      meter_definition: :allheat,
      yaxis_units:      :kw,
      yaxis_scaling:    :none,
      y2_axis:          :temperature
    },
    optimum_start:  {
      name:             'Optimum Start Control Check',
      chart1_type:      :line,
      series_breakdown: :none,
      timescale:        [{ day: Date.new(2018, 3, 16) }, { day: Date.new(2018, 3, 6) } ], # fixed dates: one relatively mild, one relatively cold
      x_axis:           :intraday,
      meter_definition: :allheat,
      yaxis_units:      :kw,
      yaxis_scaling:    :none,
      y2_axis:          :temperature
    },
    hotwater: {
      name:             'Hot Water Analysis',
      chart1_type:      :column,
      chart1_subtype:   :stacked,
      series_breakdown: :hotwater,
      x_axis:           :day,
      meter_definition: :allheat,
      yaxis_units:      :kwh
    },
    irradiance_test:  {
      name:             'Solar Irradiance Y2 axis check',
      inherits_from:    :optimum_start,
      y2_axis:          :irradiance
    },
    gridcarbon_test:  {
      name:             'Grid Carbon Y2 axis check',
      inherits_from:    :optimum_start,
      y2_axis:          :gridcarbon
    }
  }.freeze
end
