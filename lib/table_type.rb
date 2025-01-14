# define an object with api_url and fields
# use this object to pass the data to the upsert_airtable_tasks method
# this way you can easily switch between the two tables
# an object is better than a hash since it is a defined structure
# and is easier to read and understand
# this is a good example of using an object instead of a hash

class TableType
  attr_accessor :api_url, :fields

  def initialize(api_url, fields)
    @api_url = api_url
    @fields = fields
  end

  def process_fields(record)
    # iterate over the @fields and select the fields from the record
    # return a hash of the fields and values
    api_fields = {}
    @fields.each do |field|
      api_fields[field] = record[field]
    end
    api_fields
  end
end

class EpicTable < TableType


  def process_fields(record)
    api_fields = super(record)
    api_fields['Name'] = "#{api_fields['Issue']} - #{api_fields['Title']}"
    api_fields
  end
end

