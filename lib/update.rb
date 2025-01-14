# frozen_string_literal: true

require 'dotenv/load'
require 'csv'
require 'rest-client'
require 'json'
require 'logging'
require_relative 'table_type'

#
# Airtable configuration
AIRTABLE_TASK_API_URL = ENV['AIRTABLE_TASK_API_URL']
AIRTABLE_EPIC_API_URL = ENV['AIRTABLE_EPIC_API_URL']
PERSONAL_ACCESS_TOKEN = ENV['PERSONAL_ACCESS_TOKEN']


# Logging configuration
$logger = Logging.logger(STDOUT)
$logger.level = :info


# Airtable API rate limit: 5 requests per second
MAX_REQUESTS_PER_SECOND = 5

# setup for REST client to log to stdout
# RestClient.log = $stdout

# Function to get the headers for the request
def header
  {
    'Authorization': "Bearer #{PERSONAL_ACCESS_TOKEN}",
    'Content-Type': 'application/json'
  }
end

# Function to insert or update a record in Airtable
def upsert_airtable_tasks(record_id, fields, api_url)
  headers = header

  $logger.debug("Processing record: #{record_id} => #{fields}")
  begin
    if record_id
      # Update the record if record_id is present
      url = "#{api_url}/#{record_id}"
      RestClient.patch(url, { fields: fields }.to_json, headers)
    else
      # Insert new record if no record_id is provided
      url = "#{api_url}"
      RestClient.post(url, { fields: fields }.to_json, headers)
    end

    $logger.info("Record processed: #{fields['Issue']}")
  rescue RestClient::UnprocessableEntity => e
    $logger.error("Error processing record: #{record_id} => #{fields}")
    $logger.error("Error response: #{e.response}")
  rescue RestClient::ExceptionWithResponse => e
    $logger.error("Error processing record: #{record_id} => #{fields}")
    $logger.error("Error response: #{e.response}")
  rescue RestClient::Exception => e
    $logger.error("Error processing record: #{record_id} => #{fields}")
    $logger.error("Error response: #{e.message}")
  rescue StandardError
    $logger.error('Fatal error ${e.message}')
    exit 1
  end
end

# Function to process records and enforce rate limiting
def process_records(records, table_type)
  counter = 0
  start_time = Time.now

  records.each_with_index do |record, index|
    # Increment the counter for each request
    counter += 1

    ## need to add [epic record id] to the tasks
    #
    # this way you can easily switch between the two tables
    fields = table_type.process_fields(record[:fields])

    # Process the record (insert or update)
    upsert_airtable_tasks(record[:id], fields, table_type.api_url)

    # If we've reached 5 requests in a second, sleep until the next second
    if counter >= MAX_REQUESTS_PER_SECOND
      elapsed_time = Time.now - start_time
      sleep(1 - elapsed_time) if elapsed_time < 1
      # Reset counter and time
      counter = 0
      start_time = Time.now
    end
  end
end

# Function to fetch records from Airtable
# @param table_type [TableType] the object that contains the api_url and fields
# @return [Hash] a hash of records with the issue as the key and the airtable record id as the value
def fetch_airtable_records(table_type)
  headers = header

  records_hash = {}
  offset = nil
  counter = 0
  start_time = Time.now

  loop do
    url = table_type.api_url
    url += "?offset=#{offset}" if offset

    response = RestClient.get(url, headers)
    data = JSON.parse(response.body)

    data['records'].each do |record|
      records_hash[record['fields']['Issue']] = record['id']
      $logger.debug("ID: #{record['id']}: Fields: #{record['fields']}")
    end

    # Check if there are more pages to fetch
    offset = data['offset']
    break unless offset

    # Rate limiting: 5 requests per second
    counter += 1
    if counter >= MAX_REQUESTS_PER_SECOND
      elapsed_time = Time.now - start_time
      sleep(1 - elapsed_time) if elapsed_time < 1
      # Reset counter and start time
      counter = 0
      start_time = Time.now
    end
  end

  records_hash
end

# Function to match up CSV records with Airtable records to get record ids
def update_csv_records(csv_records, airtable_records)
  new_airtable_records = []

  csv_records.each do |csv_record|
    record_id = airtable_records[csv_record[:fields]['Issue']]
    new_airtable_records << { id: record_id, fields: csv_record[:fields] }
    $logger.debug("record id: #{record_id} and fields #{csv_record[:fields]}")
  end

  new_airtable_records
end

# Function to read CSV and prepare records for insertion/update
def read_csv(file_path)
  records = []
  current_date = Time.now.strftime('%Y-%m-%d')

  CSV.foreach(file_path, headers: true) do |row|

    record_id = row['Issue key'] # Assumes the CSV has a column Issue key
    duration = row['Estimates (d)'].to_i
    duration = nil if duration < 1 # use nil so we don't get a 0 duration

    fields = {
      'Title' => row['Title'], # Example: Replace with actual field names from Airtable
      'Duration' => duration,
      'Issue' => row['Issue key'],
      'Status' => row['Issue status'], # Adjust these fields based on your Airtable columns
      'Engineer' => row['Assignee'],
      'Hierarchy' => row['Hierarchy'],
      'Parent' => row['Parent'],
      'Batch Update' => current_date
    }
    $logger.debug("ID: #{record_id}: Fields: #{fields}")
    records << { id: record_id, fields: fields }
  end

  records
end

# Add the epic record id to the tasks
# convert csv_airtable_epics to a hash with the issue as the key
# then iterate over the csv_airtable_tasks and add the epic record id
def update_epic_id(csv_airtable_tasks, csv_airtable_epics)
  epics = csv_airtable_epics.to_h { |record| [record[:fields]['Title'], record[:id]] }
  csv_airtable_tasks.each do |task|
    parent = task[:fields]['Parent'] || ''
    task[:fields]['Project'] = [epics[parent]] if parent.length.positive?
  end
  csv_airtable_tasks
end


# Start of main routine
# This is where the script starts executing

task_record = TableType.new(AIRTABLE_TASK_API_URL,
                            ['Title', 'Duration', 'Issue', 'Status', 'Engineer', 'Batch Update', 'Project'])
epic_record = EpicTable.new(AIRTABLE_EPIC_API_URL, ['Name', 'Engineer', 'Status', 'Issue', 'Title', 'Batch Update'])


# Example usage
csv_file_path = ARGV[0] || 'roadmap.csv' # Replace with the path to your CSV file

# get the epic data from Airtable so we have the record ids
airtable_epics = fetch_airtable_records(epic_record)
puts("Epics from Airtable: #{airtable_epics.size}")

# Get the tasks from Airtable so we have record ids
airtable_tasks = fetch_airtable_records(task_record)
puts("Records from Airtable: #{airtable_tasks.size}")

# Read the csv into a hash
csv_records = read_csv(csv_file_path)
puts("Records from CSV: #{csv_records.size}")

# split the records into epics and tasks
csv_epics = csv_records.select { |record| record[:fields]['Hierarchy'] == 'Epic' }
csv_tasks = csv_records.reject { |record| record[:fields]['Hierarchy'] == 'Epic' }
puts("Epics: #{csv_epics.size}, Tasks: #{csv_tasks.size}")
csv_records = nil # free up the memory and keep it from being used.

# read through CSV for epics, merge with data from airtable
# and upsert the epics in Airtable
csv_airtable_epics = update_csv_records(csv_epics, airtable_epics)
puts("New epics to process: #{csv_airtable_epics.size}")
process_records(csv_airtable_epics, epic_record)
puts('Epics processing complete')

# Need to read the epics from airtable again to get IDs for any inserted records
# this is because the epic records are updated in the process_records method
airtable_epics = fetch_airtable_records(epic_record)
csv_airtable_epics = update_csv_records(csv_epics, airtable_epics)


# match up csv records with airtable records by the issue key
csv_airtable_tasks = update_csv_records(csv_tasks, airtable_tasks)

csv_airtable_tasks = update_epic_id(csv_airtable_tasks, csv_airtable_epics)
puts("New records to process: #{csv_airtable_tasks.size}")
process_records(csv_airtable_tasks, task_record)
puts('Processing complete')

