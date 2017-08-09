task :get_comps => :environment do
  comps = companyget
  comps.each do |c|
    name = c['properties']['name']['value']
    if Cost.where(title:name).empty?
      Cost.create(
      code:c['companyId'],
      title:name
      )
    end
  end
end

def companyget offset = nil
  url = BASE+"/companies/v2/companies?limit=250&hapikey=#{APIKEY}"
  puts 'looping'
  nurl = url
  nurl = url+"&offset=#{offset}" if offset
  out = goget(nurl)
  data = out['companies']
  unless out['has-more'] == true
    return data
  else
    return (data << companyget(out['offset'])).flatten
  end
end

task :load_legacy => :environment do
  cost_deals = pdget("https://api.pipedrive.com/v1/deals?filter_id=153&api_token=94c3da7b2f59297c24493e08ad1e4efdaaa58ae9")
  cost_deals.each do |c|
    if Cost.where(title:c['title']).empty?
      Cost.create(code:c['id'],title:c['title'],category:'cost center')
    end
  end
end

def pdget url,start = 0
  puts 'looping'
  url = url + "&start=#{start}"
  out = get(url)
  data = out['data']
  page = out['additional_data.pagination']
  if page['more_items_in_collection'] == false
    return data
  else 
    return (data << pdget(url,page['next_start'])).flatten
  end
end

def get url
  JSON.parse(HTTParty.get(url).body)
end