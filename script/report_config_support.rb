# test report manager
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require 'hashdiff'

class ReportConfigSupport
  include Logging
  attr_reader :schools, :chart_manager, :school
  attr_accessor :worksheet_charts, :excel_name 

  def initialize

    # @dashboard_page_groups = now in lib/dashboard/charting_and_reports/dashboard_configuration.rb
    # @school_report_groups = { # 2 main dashboards: 1 for electric only schools, one for electric and gas schools

    @schools = {
    # Bath
      'Bishop Sutton Primary School'      => :electric_and_gas,
      'Castle Primary School'             => :electric_and_gas,
      'Freshford C of E Primary'          => :electric_and_gas,
      'Marksbury C of E Primary School'   => :electric_only,
      'Paulton Junior School'             => :electric_and_gas_and_solar_pv,
      'Pensford Primary'                  => :electric_only,
      'Roundhill School'                  => :electric_and_gas,
      'Saltford C of E Primary School'    => :electric_and_gas,
      'St Marks Secondary'                => :electric_and_gas,
      'St Johns Primary'                  => :electric_and_gas,
      'St Saviours Junior'                => :electric_and_gas,
      'Stanton Drew Primary School'       => :electric_and_storage_heaters,
      'St Martins Garden Primary School'  => :electric_and_gas,
      'St Michaels Junior Church School'  => :electric_and_gas,
      'Twerton Infant School'             => :electric_and_gas,
      'Westfield Primary'                 => :electric_and_gas,
    # Sheffield
      'Athelstan Primary School'          => :electric_and_gas,
      'Bankwood Primary School'           => :electric_and_gas,
      'Ballifield Community Primary School' => :electric_and_gas,
      'Coit Primary School'               => :gas_only,
 #     'Ecclesall Primary School'          => :electric_and_gas,
      'Ecclesfield Primary School'        => :electric_and_gas,
      'Hunters Bar School'                => :electric_and_gas,
      'King Edward VII Upper School'      => :electric_and_gas,
      'Lowfields Primary School'          => :electric_only,
      'Meersbrook Primary School'         => :electric_and_gas,
      'Mundella Primary School'           => :electric_and_gas,
      'Phillimore School'                 => :electric_and_gas,
      'Shortbrook School'                 => :electric_and_gas,
      'Valley Park School'                => :electric_only,
      'Watercliffe Meadow Primary'        => :electric_and_gas,
      'Walkley Tennyson School'           => :gas_only,
      'Whiteways Primary'                 => :electric_and_gas,
      'Woodthorpe Primary School'         => :electric_and_gas,
      'Wybourn Primary School'            => :electric_only,
    # Frome
      'Christchurch First School'         => :gas_only,
      'Critchill School'                  => :electric_and_gas,
      'Frome College'                     => :electric_only,
      'Hayesdown First School'            => :electric_only,
      'Oakfield School'                   => :electric_and_gas,
      'Selwood Academy'                   => :electric_and_gas,
      'St Johns First School'             => :electric_and_gas,
      'St Louis First School'             => :electric_and_gas,
      'Trinity First School'              => :electric_and_gas,
      'Vallis First School'               => :electric_and_gas,
    # Average and Exemplar
      'Average School'                    => :electric_and_gas,
    }
    @benchmarks = []

    ENV['School Dashboard Advice'] = 'Include Header and Body'
    $SCHOOL_FACTORY = SchoolFactory.new

    @chart_manager = nil
    @school_metadata = nil
    @worksheet_charts = {}
    @failed_reports = []
    @differing_results = []

    logger.debug "\n" * 8
  end

  def self.suppress_output(school_name)
    begin
      original_stdout = $stdout.clone
      $stdout.reopen(File.new('./Results/' + school_name + 'loading log.txt', 'w'))
      retval = yield
    rescue StandardError => e
      $stdout.reopen(original_stdout)
      raise e
    ensure
      $stdout.reopen(original_stdout)
    end
    retval
  end

  def do_all_schools(suppress_debug = false)
    @schools.keys.each do |school_name|
      load_school(school_name, suppress_debug)
      do_all_standard_pages_for_school
    end
    report_failed_charts
  end

  def report_failed_charts
    puts '=' * 100
    puts 'Failed charts'
    @failed_reports.each do |school_name, chart_name|
      puts sprintf('%-25.25s %-45.45s', school_name, chart_name)
    end
    puts '-' * 100
    puts 'Differing charts'
    @differing_results.each do |difference|
      puts difference
    end
    puts '_' * 120
  end

  def self.banner(title)
    cols = 120
    len_before = ((cols - title.length) / 2).floor
    len_after = cols - title.length - len_before
    '=' * len_before + title + '=' * len_after
  end

  def setup_school(school, school_name)
    @school_name = school_name
    @school = school
    @chart_manager = ChartManager.new(@school)
  end

  def load_school(school_name, suppress_debug = false)
    logger.debug self.class.banner("School: #{school_name}")

    puts self.class.banner("School: #{school_name}")

    @excel_name = school_name

    @school_name = school_name

    @school = $SCHOOL_FACTORY.load_or_use_cached_meter_collection(:name, school_name, :analytics_db)

    @chart_manager = ChartManager.new(@school)
    
    @school # needed to run simulator
  end

  def report_benchmarks
    @benchmarks.each do |bm|
      puts bm
    end
    @benchmarks = []
  end

  def do_all_standard_pages_for_school(chart_override = nil, name_override = nil)
    @worksheet_charts = {}

    meter_collection_config = @school.report_group
    
    report_config = @schools[@school_name]

    if report_config != meter_collection_config
      puts "|" * 100
      puts "\n" * 10
      puts "Mismatch in report config #{report_config} versus #{meter_collection_config}"
    end
    report_config = meter_collection_config if report_config.nil?
    
    report_groups = DashboardConfiguration::DASHBOARD_FUEL_TYPES[report_config]

    report_groups.each do |report_page|
      do_one_page(report_page, false, chart_override, name_override)
    end

    save_excel_and_html
  end

  def save_excel_and_html
    write_excel
    write_html
    # @worksheet_charts = {}
  end

  def do_one_page(page_config_name, reset_worksheets = true, chart_override = nil, name_override = nil)
    @worksheet_charts = {} if reset_worksheets
    page_config = DashboardConfiguration::DASHBOARD_PAGE_GROUPS[page_config_name]
    worksheet_tab_name = name_override.nil? ? page_config[:name] : name_override.to_s
    do_one_page_internal(worksheet_tab_name, page_config[:charts], chart_override)
  end

  def do_chart_list(page_name, list_of_charts)
    @worksheet_charts = {}
    do_one_page_internal(page_name, list_of_charts)
  end

  def write_excel
    excel = ExcelCharts.new(File.join(File.dirname(__FILE__), '../Results/') + @excel_name + '- charts test.xlsx')
    @worksheet_charts.each do |worksheet_name, charts|
      excel.add_charts(worksheet_name, charts)
    end
    excel.close
  end

  def write_html
    html_file = HtmlFileWriter.new(@school_name)
    @worksheet_charts.each do |worksheet_name, charts|
      html_file.write_header(worksheet_name)
      charts.each do |chart|
        html_file.write_header_footer(chart[:config_name], chart[:advice_header], chart[:advice_footer])
      end
    end
    html_file.close
  end

  def do_one_page_internal(page_name, list_of_charts, chart_override = nil)
    logger.debug self.class.banner("Running report page  #{page_name}")
    @worksheet_charts[page_name] = []
    list_of_charts.each do |chart_name|
      charts = do_charts_internal(chart_name, chart_override)
      save_and_compare_chart_data(chart_name, charts) if defined?(@@energysparksanalyticsautotest)
      unless charts.nil?
        charts.each do |chart|
          ap(chart, limit: 20, color: { float: :red }) if ENV['AWESOMEPRINT'] == 'on'
          @worksheet_charts[page_name].push(chart) unless chart.nil?
        end
      end
    end
  end

  def save_and_compare_chart_data(chart_name, charts)
    if chart_name.is_a?(Hash)
      puts 'Unable to save and compare composite chart'
      return
    end
    save_chart(@@energysparksanalyticsautotest[:new_data], chart_name, charts)
    previous_chart = load_chart(@@energysparksanalyticsautotest[:original_data], chart_name)
    if previous_chart.nil?
      puts "Chart comparison: for #{@school_name}:#{chart_name} is missing from benchmark chart list"
      return
    end
    compare_charts(chart_name, previous_chart, charts)
  end

  def compare_charts(chart_name, old_data, new_data)
    diff = old_data == new_data
    unless diff # HashDiff is horribly slow, so only run if necessary
      puts "+" * 120
      puts "Chart #{chart_name} differs"
      h_diff = HashDiff.diff(old_data, new_data, use_lcs: false, :numeric_tolerance => 0.01) # use_lcs is O(N) otherwise and takes hours!!!!!
      if @@energysparksanalyticsautotest[:skip_advice] && h_diff.to_s.include?('html')
        puts 'Advice differs'
      else
        if h_diff.to_s.length > 50
          puts "Lots of differences #{h_diff.to_s.length} length"
        else
          ap(h_diff)
        end
      end
      @differing_results.push(sprintf('%30.30s %20.20s %s', @school_name, chart_name, h_diff))
      puts "+" * 120
    end
  end

  def load_chart(path, chart_name)
    yaml_filename = yml_filepath(path, chart_name)
    return nil unless File.file?(yaml_filename)
    meter_readings = YAML::load_file(yaml_filename)
  end

  def save_chart(path, chart_name, data)
    yaml_filename = yml_filepath(path, chart_name)
    File.open(yaml_filename, 'w') { |f| f.write(YAML.dump(data)) }
  end

  def yml_filepath(path, chart_name)
    full_path ||= File.join(File.dirname(__FILE__), path)
    Dir.mkdir(full_path) unless File.exists?(full_path)
    extension = @@energysparksanalyticsautotest.key?(:name_extension) ? ('- ' + @@energysparksanalyticsautotest[:name_extension].to_s) : ''
    yaml_filename = full_path + @school_name + '-' + chart_name.to_s + extension + '.yaml'
    yaml_filename.length > 259 ? shorten_filename(yaml_filename) : yaml_filename
  end

  # deal with Windows 260 character filepath limit
  def shorten_filename(yaml_filename)
    yaml_filename.gsub(/ School/,'').gsub(/ Community/,'')
  end

  def do_charts_internal(chart_name, chart_override)
    if chart_name.is_a?(Symbol)
      logger.debug self.class.banner(chart_name.to_s)
    else
      logger.debug "Running Composite Chart #{chart_name[:name]}"
    end
    chart_results = nil
    bm = Benchmark.measure {
      chart_results = @chart_manager.run_chart_group(chart_name, chart_override)
    }
    @benchmarks.push(sprintf("%20.20s %40.40s = %s", @school.name, chart_name, bm.to_s))
    if chart_results.nil?
      @failed_reports.push([@school.name, chart_name])
      puts "Nil chart result from #{chart_name}"
    end
    if chart_name.is_a?(Symbol)
      [chart_results]
    else
      chart_results[:charts]
    end
  end
end
