# test report manager
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'

# school_name = 'Westfield Primary' 
module Logging
  @logger = Logger.new('Results/test-simulator-fit ' + Time.now.strftime('%H %M') + '.log')
  @logger.level = :debug # :debug
end
ENV['AWESOMEPRINT'] = 'off'

puts "========================================================================================"
puts  "electrical simulation"

suppress_school_loading_output = true

reports = ReportConfigSupport.new

list_of_schools = reports.schools.keys

list_of_schools.each do |school_name|
  school = nil
  school_name = 'St Marks Secondary'
  puts "Processing #{school_name}"
  bm = Benchmark.measure {
    school = reports.load_school(school_name, suppress_school_loading_output)
  }
  puts "Load took: #{bm.to_s}"
  simulator = ElectricitySimulator.new(school)

  bm = Benchmark.measure {
 #   simulator.simulate(simulator.default_simulator_parameters)
  }
  puts "Simulator took: #{bm.to_s}"

  fitted_parameters = nil
  parameters = nil
  bm = Benchmark.measure {
    # call one or the other of these
    parameters = simulator.fit(simulator.default_simulator_parameters)
    # parameters = simulator.exemplar(simulator.default_simulator_parameters)
  }
  puts "Fitting took: #{bm.to_s}"

  # ap(fitted_parameters)
  bm = Benchmark.measure {
     simulator.simulate(parameters)
  }
  puts "Simulator took: #{bm.to_s}"

  puts 'Actual:'
  actual_stats = simulator.actual_data_statistics
  puts 'Simulator'
  simulator_stats = simulator.simulator_data_statistics

  reports.do_one_page(:simulator)
  reports.do_one_page(:simulator_detail, false)

  reports.excel_name = school_name + ' - simulator fitter'

  reports.save_excel_and_html

  reports.report_benchmarks

  exit
end

