class TimesController < ApplicationController
  APIKEY = 'b87e12c0-5e5f-4b77-b5de-d7061a9cc002'
  BASE = "https://api.hubapi.com"
  TYPES = ['time','call','vendor','onsite']
  SLACK_BASE = "https://slack.com/api/"

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
    HTTParty.get(SLACK_BASE+"users.info?token=#{ENV['SLACK_TOKEN']}&user=#{id}").parsed_response['user']['tz']
  end
  
  def getemail(id)
    HTTParty.get(SLACK_BASE+"users.info?token=#{ENV['SLACK_TOKEN']}&user=#{id}").parsed_response['user']['profile']['email']
  end
  
  def realname(id)
    HTTParty.get(SLACK_BASE+"users.info?token=#{ENV['SLACK_TOKEN']}&user=#{id}").parsed_response['user']['profile']['real_name']
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
  
  def newcost
    c = Cost.where(category:'cost center').pluck(:code).max
    Cost.create(title:params['text'],code:c+1,category:'cost center')
    render :json => "Added #{params['text']}, code #{c+1}"
  end
  
  def standup
    u = User.find_or_create_by(slackid:params['user_id'])
    
    tz = localtime(u.slackid)
    date = DateTime.now.in_time_zone(tz).strftime("%Y-%m-%d")
    
    out = ""
    ents = Entry.where(date:date,user_id:u.id)
    out << "Today you've done #{ents.pluck(:time).sum} total:"
    if ents.empty?
      out << "\nNothing recorded"
    else
      ents.each do |e|
        out << "\n#{e.title} (#{e.deal_id}): #{e.time}"
        out << " – #{e.note}" unless e.note.nil? || e.note.empty?
      end
    end
    render :json => {"response_type": "in_channel","text": out}.to_json
  end
end
