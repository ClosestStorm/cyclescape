class PlanningApplicationsProcessor

require 'net/http'
require 'tempfile'
require 'csv'
require 'progressbar'

  def self.process_planning_applications
    processor = self.new
    processor.run
  end

  def run
    begin
      #fetch_zipfile
      #unzip_file
      process_csv
    ensure
      cleanup
    end
  end

  def fetch_zipfile
    # Ensure that we don't have the file in memory when downloading
    uri = URI("http://thunderflames.org/temp/planning_applications.zip")
    @tempfile = Tempfile.new('cyclekit-zip')
    @tempfile.binmode

    Net::HTTP.start(uri.host, uri.port) do |http|
      request = Net::HTTP::Get.new uri.request_uri

      http.request request do |response|
        response.read_body do |chunk|
          @tempfile.write chunk
        end
      end
    end
    @tempfile.close
  end

    def unzip_file
      @tempfile.open
      @csv_path = Tempfile.new('cyclekit-unzip').path
      system("unzip -p #{@tempfile.path} > #{@csv_path}")
    end

  def process_csv
    @csv_path = '/home/andy/temp/cyclestreets/planning applications/planning_applications.head10k.csv'

    # use wc for optimal speed :-)
    csv_length = %x{wc -l "#{@csv_path}"}.to_i

    # Create a progress bar using the length of the file
    pbar = ProgressBar.new("Updating", csv_length)

    # Suppress the activerecord logging, so that we can see the progressbar
    ActiveRecord::Base.logger = Logger.new('/dev/null')

    ActiveRecord::Base.transaction do
      csv = CSV.foreach(@csv_path, headers: true, header_converters: :symbol) do |row|
        record = PlanningApplication.find_by_openlylocal_id(row[:openlylocal_id])
        record = PlanningApplication.new unless record
        [:openlylocal_id, :openlylocal_url, :address, :postcode, :description, :council_name, :url, :uid].each do |symbol|
          record[symbol] = row[symbol]
        end
        record[:openlylocal_council_url] = row[:council_openlylocal_url]
        record.location = "POINT(#{row[:lng]} #{row[:lat]})"
        # Unhandled symbols:
        # updated_at retrieved_at decision status date_received date_validated start_date
        record.save!
        pbar.inc
      end
    end

    pbar.finish
  end

  def cleanup
    @tempfile.close if @tempfile
  end
end