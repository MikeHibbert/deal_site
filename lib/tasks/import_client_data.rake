require 'csv'

def get_dates(row)
  begin_date = nil
  end_date = nil

  parts = row.split(' ')

  begin_date_found = false
  parts.each do |part|
    begin
      Date.parse(part)

      if part.include?('/')
        unless begin_date_found
          begin_date_found = true
          begin_date = part
          row.sub! " #{part} ", ","
        else
          end_date = part
          row.sub! "#{part}", ''
        end
      end
    rescue
    end
  end

  # make sure that a end dat is generated with default +1.month from beginning
  unless end_date
    end_date = Date.parse(begin_date) + 1.month
    end_date = end_date.strftime("%d/%m/%Y")
  end

  return begin_date, end_date
end


def get_merchant(row)
  parts = row.split(',')
  merchant = parts[0]
  row.sub! "#{merchant}, ", ''

  merchant
end


def get_price_and_value(row)
  parts = row.split(' ')
  price = nil
  value = nil
  price_found = false

  parts.each do |part|
    begin
      i = Integer(part)
      if price_found
        value = i
        row.sub! " #{part}", ''
      else
        price = i
        price_found = true
        row.sub! " #{part}", ''
      end
    rescue
    end
  end

  return price, value
end


def get_deal(row)
  row.sub! "\n", '' # trim off any line endings
  row.lstrip!
  row.rstrip!
end


def create_new_deal(publisher, merchant, deal, begin_date, end_date, price, value)
  a = Advertiser.find_by_name(merchant)

  unless a
    a = publisher.advertisers.create!(:name => merchant)
  end

  d = Deal.find_by_proposition(deal)
  unless d
    a.deals.create!(
        proposition: deal,
        value: Integer(value),
        price: Integer(price),
        description: deal,
        start_at: Date.parse(begin_date),
        end_at: Date.parse(end_date)
    )
  end
end


namespace :db do
  desc "Import publishers data from a .txt file"
  task :import_publisher_data, :publisher_name, :file_path, :needs => :environment do |t, args|
    unless args[:file_path]
      raise 'Please use: rake db:import_publisher_data["<publisher name>",<path to file>]\n'
    end

    unless args[:publisher_name]
      raise 'Please use: rake db:import_publisher_data["<publisher name>",<path to file>]\n'
    end

    unless File.exists?(Rails.root.join(args[:file_path]))
      raise "Cant find #{file_path}!"
    end

    # create the publisher
    publisher = Publisher.find_by_name(args[:publisher_name])
    unless publisher
      theme = args[:publisher_name].downcase.gsub(' ', '-')
      publisher = Publisher.create!(:name => args[:publisher_name],
                                    :theme => "entertainment-#{args[:publisher_name].downcase.gsub(' ', '-')}")
    end

    import_text = File.read(Rails.root.join(args[:file_path]))

    headers_read = false
    import_text.each_line do |row|
      if headers_read
        merchant = nil
        begin_date = nil
        end_date = nil
        deal = nil
        price = nil
        value = nil

        begin_date, end_date = get_dates(row)

        merchant = get_merchant(row)

        price, value = get_price_and_value(row)

        deal = get_deal(row)

        create_new_deal(publisher, merchant, deal, begin_date, end_date, price, value)
      else
        headers_read = true
      end
    end
  end
end