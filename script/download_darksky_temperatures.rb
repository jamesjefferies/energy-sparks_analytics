# test report manager
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'

module Logging
  @logger = Logger.new(STDOUT)
end

INPUT_DATA_DIR = File.join(File.dirname(__FILE__), '../InputData')

def csv_last_reading(filename)
  last_date = nil
  if File.exist?(filename)
    File.open(filename, 'r') do |file|
      last_date = Date.parse(file.readlines.last.split(',')[0])
    end
  end
  last_date
end

def write_csv(filename, data, append)
  mode = append ? "Appending" : "Writing"
  puts "#{mode} csv file #{filename}: #{data.length} items from #{data.keys.first} to #{data.keys.last}"
  File.open(filename, append ? 'a' : 'w') do |file|
    data.each do |date, one_days_values|
      dts = date.strftime('%Y-%m-%d')
      file.puts("#{dts}," + one_days_values.join(','))
    end
  end
end

def start_end_dates(csv_filename)
  new_file = true
  end_date = Date.today - 1
  last_reading_date = csv_last_reading(csv_filename)
  if last_reading_date.nil?
    start_date = end_date - 365
  else
    new_file = false
    start_date = last_reading_date + 1
  end
  [start_date, end_date, new_file]
end

locations = {
  'Bath'      => { latitude: 51.39,   longitude: -2.37,   csv_filename: 'Bath temperaturedata.csv' },
  'Sheffield' => { latitude: 53.3811, longitude: -1.4701, csv_filename: 'Sheffield temperaturedata.csv' },
  'Frome'     => { latitude: 51.2308, longitude: -2.3201, csv_filename: 'Frome temperaturedata.csv'},
}

darksky = DarkSkyWeatherInterface.new

puts
puts 'DARK SKY TEMPERATURE DOWNLOAD'
puts 
puts 'Appending data to existing csv files'
puts

locations.each do |city, config|
  puts
  puts "===============================#{city}======================================"
  csv_filename = "#{INPUT_DATA_DIR}/" + config[:csv_filename]
  start_date, end_date, new_file = start_end_dates(csv_filename)
  puts "Downloading data for #{city} from #{start_date} to #{end_date} and adding to #{csv_filename}"

  if start_date > end_date
    puts 'csv file already up to date'
  else
    distance_to_weather_station, temperature_data, percent_bad, bad_data = darksky.historic_temperatures(config[:latitude], config[:longitude], start_date, end_date)
    write_csv(csv_filename, temperature_data, !new_file)
    puts "Saving dates from #{start_date} to #{end_date} to csv file"
    puts "Distance of weather station to location #{distance_to_weather_station}"
    puts "Percentage bad data: #{(percent_bad * 100.0).round(2)}%"
    bad_data.each do |problem|
      puts "    Problem with: #{problem}"
    end
  end
end
