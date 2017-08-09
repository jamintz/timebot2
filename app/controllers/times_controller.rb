class TimesController < ApplicationController

  APIKEY = 'b87e12c0-5e5f-4b77-b5de-d7061a9cc002'
  BASE = "https://api.hubapi.com"
  TYPES = ['time','call','vendor','onsite']

  def getuser(email)
    resp = RestClient.get(BASE+"/owners/v2/owners?hapikey=#{APIKEY}")
    h = JSON.parse(resp.body)
    ids = h.select{|x|x['email']==email}
    [ids.first['firstName'],ids.first['lastName']].join(' ') unless ids.empty?
  end
  
  def is_number? string
    true if Float(string) rescue false
  end
  
  def goget url
    JSON.parse(HTTParty.get(url).body)
  end

  def localtime id
    @sl = get_slack
    @sl.users_info(user:id).user.tz
  end

  def getdeal(id)
    resp = RestClient.get(BASE+"/deals/v1/deal/#{id}?hapikey=#{APIKEY}")
    JSON.parse(resp.body)
  end
  
  def getemail(id)
    @sl = get_slack
    @sl.users_info(user:id).user.profile.email
  end
  
  def realname(id)
    @sl = get_slack
    @sl.users_info(user:id).user.profile.real_name
  end
  
  def get_slack
    token = 'xoxb-130027786769-Zcw6veISkzlUdoPAaOW6i3Aw'
    Slack.configure do |config|
      config.token = token
    end
    @sl || Slack::Web::Client.new
  end
  
  def weekdate(tz)
    today = DateTime.now.in_time_zone(tz).to_date
    wd = today.wday == 0 ? 7 : today.wday - 1
    date = (today - wd).strftime("%Y-%m-%d")
  end
  
  def find
    term = params['text'].split(' ')
    if term.empty?
      render :json => 'What deal are you looking for?'
      return
    end
    out = ""
    Cost.all.select{|x|term.all?{|w|x.title.downcase.include?(w.downcase)}}.each do |x|
      out = out+"#{x.code}: #{x.title}\n"
    end
    out = 'None found' if out.empty?
    render :json => out
  end
  
  def save
    u = User.find_or_create_by(slackid:params['user_id'])
    id = params['text']
    
    deal = Cost.where(code:id)
    if deal.empty?
      render :json => "Deal not found"
    else
      Favorite.create(user_id:u.id,cost_id:deal.first.id)
      render :json => "Added #{deal.first.title} to favorites"
    end
  end
  
 def favorites
   u = User.find_or_create_by(slackid:params['user_id'])
   out = ""
   u.favorites.each{|x|out = out + "\n#{x.cost.title} – #{x.cost.code}"}
   render :json => out
 end
    
  def remove
    u = User.find_or_create_by(slackid:params['user_id'])
    id = params['text']
    c = Cost.where(code:id).first
    if c.nil?
      render :json => "Deal not found"
    else
      Favorite.where(user_id:u.id,cost_id:c.id).destroy_all
      render :json => "Deal #{c.title} removed from favorites"
    end
  end
  
  def add
    begin
      note = nil
      exp = params['text'].split(' ')
      if exp.length < 2 || !is_number?(exp[1]) || (!is_number?(exp[0]) && !is_number?(exp[2]))
          render :json => "Please enter a code and an amount of time"
      elsif !is_number?(exp[0]) && !TYPES.include?(exp[0].downcase)
        render :json => "Supported activity types are time, onsite, call, and vendor"
      else
        u = User.find_or_create_by(slackid:params['user_id'])
        u.name ||= realname(u.slackid)
        u.email ||= getemail(u.slackid)
        u.save!
        
        tz = localtime(u.slackid)
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
                      
        if time > 40
          render :json => "You can only add up to 40 hours at a time"
        else   
          begin
            title = Cost.where(code:deal).first.title
            Entry.create(
            user_id:u.id,
            email:u.email,
            date:due,
            deal_id:deal,
            kind:kind,
            note:note,
            time:time,
            title:title,
            user_name:u.name
            ) 
            render :json => "Thanks! #{time} added to #{deal} (#{title}) for #{due}"
          rescue
            render :json => "Deal not found"
          end
        end

      end
    rescue
      render :json => "Sorry, didn't understand that"
    end
  end
  
  def runget(type,client,data,match)
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

end
