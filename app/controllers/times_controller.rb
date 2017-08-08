class TimesController < ApplicationController

  APIKEY = 'b87e12c0-5e5f-4b77-b5de-d7061a9cc002'
  BASE = "https://api.hubapi.com"
  TYPES = ['time','call','vendor','onsite']

  def self.getuser(email)
    resp = RestClient.get(BASE+"/owners/v2/owners?hapikey=#{APIKEY}")
    h = JSON.parse(resp.body)
    ids = h.select{|x|x['email']==email}
    [ids.first['firstName'],ids.first['lastName']].join(' ') unless ids.empty?
  end
  
  def self.is_number? string
    true if Float(string) rescue false
  end

  def self.localtime id
    @sl = get_slack
    @sl.users_info(user:id).user.tz
  end
  
  def self.gettasks(user,date,type)
    resp = RestClient.get("https://api.pipedrive.com/v1/activities?user_id=#{user}&start_date=#{date}&done=1&api_token=#{KEY}&type=#{type}")
    JSON.parse(resp.body)
  end
  
  def self.getdeal(id)
    resp = RestClient.get(BASE+"/deals/v1/deal/#{id}?hapikey=#{APIKEY}")
    JSON.parse(resp.body)
  end
  
  def self.getdeals offset=nil
    url = BASE+"/deals/v1/deal/paged?hapikey=#{APIKEY}&properties=dealname"
    puts 'looping'
    url = url+"&offset=#{offset}" if offset
    out = JSON.parse(RestClient.get(url).body)     
    data = out['deals']
    unless out['hasMore'] == true
      return data
    else
      return (data << getdeals(out['offset'])).flatten
    end
  end
  
  def self.getemail(id)
    @sl = get_slack
    email = @sl.users_info(user:id).user.profile.email
  end
  
  def self.get_slack
    @sl || Slack::Web::Client.new
  end
  
  def self.weekdate(tz)
    today = DateTime.now.in_time_zone(tz).to_date
    wd = today.wday == 0 ? 7 : today.wday - 1
    date = (today - wd).strftime("%Y-%m-%d")
  end
  
  def find
    deals = getdeals
    term = params['text'].split(' ')
    out = ""
    deals.select{|x|term.all?{|w|x['properties']['dealname']['value'].downcase.include?(w.downcase)}}.each do |x|
      out = out+"#{x['properties']['dealname']['value']}: #{x['dealId']}\n"
    end
    out = 'None found' if out.empty?
    client.say(channel:data.channel,text:out)
  end
  
  def save
    id = params['text']
    begin
     t = getdeal(id)
     title = t['properties']['dealname']['value']
     if title
       x = @r.get(data.user.to_s)      
       h = x.nil? ? {} : JSON.parse(x)
       h[id] = title
       @r.set(data.user,h.to_json)
       client.say(channel:data.channel,text:"Deal #{id} – #{title} added to favorites")
     else
       client.say(channel:data.channel,text:"Deal not found")
     end
   rescue
     client.say(channel:data.channel,text:"Deal not found")
   end
  end
  
 def favorites
    x = @r.get(data.user.to_s)
    if x && !x.empty?
      h = JSON.parse(x)
      out = ""
      h.each{|x|out = out + "\n#{x.first} – #{x.last}"}
      client.say(channel:data.channel,text:"Your favorites: #{out}")
    else
      client.say(channel:data.channel,text:"None found")
    end
  end
    
  def remove
    id = match['expression']
    x = @r.get(data.user.to_s)
    h = x.nil? ? {} : JSON.parse(x)
    fav = h[id]
    if fav
      h.delete(id)
      @r.set(data.user,h.to_json)
      client.say(channel:data.channel,text:"Deal #{id} removed from favorites")
    else
      client.say(channel:data.channel,text:"Deal not found")
    end
  end
  
  def totals
    begin
      limit = match['expression'] == 'limit' ? true : false
      @sl = get_slack
      ids = []
      
      client.say(channel:data.channel, text:'Calculating, please wait (this is slow)...')   
      
      us = @sl.users_list['members'].select{|x|x['profile']['email'] && x['profile']['email'].include?('@demystdata.com') && !x.deleted}
      
      us.each do |i|
        mail = i.profile.email
        ids << [i.real_name,getpid(mail),i.tz]
      end
      out = []
      ids.each do |name,id,tz|
        date = weekdate(tz)
        next unless id
        time = 0
        h = 0
        m = 0
        as = []
        TYPES.each do |k|
          as << gettasks(id,date,k)['data']
        end
        as = as.flatten.compact
        as.each do |a|
          dur = a['duration'].empty? ? ['00','00'] : a['duration'].split(':')
          h += dur.first.to_i
          m += dur.last.to_i
        end
        time += h*60
        time += m
        
        tot = time==0 ? "#{name} – Nothing recorded" : "#{name} – #{(time/60.0).round(1)}"
        out << "#{tot}" unless time == 0 && limit
      end
      client.say(channel:data.channel, text:out)
    rescue
      client.say(channel:data.channel, text:"Sorry, didn't understand that")
    end
  end
  
  def add
    begin
      note = nil
      exp = match['expression'].split(' ')
      if exp.length < 2 || !is_number?(exp[1]) || (!is_number?(exp[0]) && !is_number?(exp[2]))
          client.say(channel:data.channel, text:"Please enter a code and an amount of time")
      elsif !is_number?(exp[0]) && !TYPES.include?(exp[0].downcase)
        client.say(channel:data.channel, text:"Supported activity types are time, onsite, call, and vendor")
      else
        email = getemail(data.user)
        user = getuser(email)
        tz = localtime(data.user)
        due = DateTime.now.in_time_zone(tz).strftime("%Y-%m-%d")
        zone = ActiveSupport::TimeZone[tz]
        
        Chronic.time_class = zone
        if exp.count >= 2
          if is_number?(exp[0])
            kind = 'time'
            e2 = exp[2..-1].join(' ')
            time = exp[1].to_f
            deal = exp[0]
          else
            kind = exp[0]
            e2 = exp[3..-1].join(' ')
            time = exp[2].to_f
            deal = exp[1]
          end
          
          if e2.include?('||')
            spl = e2.split('||')
            dat = c(spl.first)
            due = dat.strftime("#{Date.today.year}-%m-%d") if dat
            note = spl.last.strip
          else
            dat = Chronic.parse(e2)
            if dat
              due = dat.strftime("#{Date.today.year}-%m-%d")
            else
              note = e2.strip
            end
          end
        end
                      
        if hours > 40
          client.say(channel: data.channel, text: "You can only add up to 40 hours at a time")
        else   
          begin      
            hdeal = getdeal(deal)
            body = 
            {
              "user":user,
              "kind":kind,
              "time":time,
              "date":due,
              "title":hdeal['properties']['dealname']['value'],
              "note":note,
              "hsdeal_id":hdeal['dealId']
            }
            RestClient.post("SCORECARDURL/time_expenses/add",body)   
            out = "Thanks <@#{data.user}>! #{time} for you added to code #{res['deal_id']}, #{res['deal_title']} on #{due} for #{kind}"
            out = out +  " with note: #{note}" if note && note != ""
            client.say(channel: data.channel, text: out)
          rescue
            client.say(channel:data.channel, text:"Deal not found")
          end
        end

      end
    rescue
      client.say(channel:data.channel, text:"Sorry, didn't understand that")
    end
  end
  
  def self.runget(type,client,data,match)
    tz = localtime(data.user)
    
    case type
      when 'get'
        date = weekdate(tz)
        open = "This week"
      when 'stand'
        date = DateTime.now.in_time_zone(tz).strftime("%Y-%m-%d")
        open = "Today"
      else raise exception
    end
      
    pid = nil
    # begin
      if match['expression']
        @sl = get_slack
        name = match['expression'].gsub(/[^0-9a-z ]/i, '')
        pid = getuser(name) 
        greet = "#{@sl.users_info(user:name).user.real_name} has"
      else
        pid = getuser(data.user)
        greet = "you've"
      end
      if pid.nil? 
        client.say(channel:data.channel,text:'User not found')
      else
        as = []
        TYPES.each do |k|
          as << gettasks(pid,date,k)['data']
        end
        as = as.flatten.compact

        hashes = []
        as.each do |a|
          id = a['deal_id'] || 'Unknown'
          exist = hashes.select{|x|x['id']==id}
          hash = exist.empty? ? Hash.new(0) : exist.first
          hash['note'] = nil if hash['note'] == 0
          hash['id'] = id
          hash['note'] = (hash['note'].nil? ? a['note'] : (hash['note'] + ", " + a['note'])) if type == 'stand' && !a['note'].empty? && (hash['note'].nil? || !hash['note'].include?(a['note']))
          dur = a['duration'].empty? ? ['00','00'] : a['duration'].split(':')
          h = dur.first.to_i
          m = dur.last.to_i
          
          deal = a['deal_title'] || 'Unknown'
          hash['title'] = deal
          
          hash['time'] += (h*60+m)
          hashes << hash if exist.empty?
        end
        tot = 0
        out = ""
        hashes.each do |h|
          ending = nil
          ending = " – #{h['note']}" if h['note']
          am = (h['time']/60.0).round(1)
          tot += am
          out = out + "#{h['title']} (#{h['id']}): #{am}#{ending}\n"
        end
        out = "Nothing recorded" if out.empty?
        client.say(channel: data.channel, text:"#{open} #{greet} done #{tot.round(1)} total:\n#{out}")
      end
    # rescue
    #   client.say(channel:data.channel, text:"Sorry, didn't understand that")
    # end
  end
  
  def standup
    runget('stand',client,data,match)
  end

  def get
    runget('get',client,data,match)
  end
end
