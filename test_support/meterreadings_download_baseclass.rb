require_relative '../app/services/aggregate_data_service'
require_relative '../app/models/meter_collection'
# Base class for downloading/storing meter readings from various external sources
class MeterReadingsDownloadBase
  include Logging

  attr_reader :school_name, :postcode

  def initialize(meter_collection)
    @meter_collection = meter_collection
    @school_name = meter_collection.name
    @postcode = meter_collection.postcode
  end

  def load_meter_readings
    throw EnergySparksAbstractBaseClass.new('Unexpected call to abstract base class (load_meter_readings)')
  end

  def save_meter_readings
    throw EnergySparksAbstractBaseClass.new('Unexpected call to abstract base class (save_meter_readings)')
  end

  def self.meter_reading_factory(download_type, meter_collection)
    puts "Creating a meter reading download of type #{download_type}" # not sure how to access logger?
    case download_type
    when :bathcsv
      LoadSchoolFromBathSplitCSVFile.new(meter_collection)
    when :bathhacked
      BathHackedSocrataDownload.new(meter_collection)
    when :fromecsv
      LoadSchoolFromFromeFiles.new(meter_collection)
    when :analytics_db
      LocalAnalyticsMeterReadingDB.new(meter_collection)
    when :sheffieldcsv
      LoadSchoolFromSheffieldCSV.new(meter_collection)
    when :downloadfromfrontend 
      LoadSchoolFromFrontEndDownload.new(meter_collection)
    else
      throw EnergySparksUnexpectedStateException.new('Unknown download type') if download_type.nil?
      throw EnergySparksUnexpectedStateException.new("Unknown download type #{download_type}") if !download_type.nil?
    end
  end

  protected

  def subdirectory
    ''
  end

  def directory
    meterreadings_cache_directory + subdirectory + '/'
  end

  def meterreadings_cache_directory
    ENV['CACHED_METER_READINGS_DIRECTORY'] ||= File.join(File.dirname(__FILE__), '../MeterReadings/')
    ENV['CACHED_METER_READINGS_DIRECTORY']
  end
end
