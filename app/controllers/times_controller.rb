# coding: utf-8
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
    #    puts "users.info?token=#{ENV['SLACK_TOKEN']}&user=#{id}"
    foo = HTTParty.get(SLACK_BASE+"users.info?token=#{ENV['SLACK_TOKEN']}&user=#{id}").parsed_response
    #    puts foo
    bar = foo['user']
    #    puts bar
    baz = bar['tz']
    return baz
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
    u = User.find_or_create_by(slackid: params['user_id'])
    id = params['text']

    deal = Cost.where(code:id)
    if deal.empty?
      render :json => "Deal not found"
    else
      Favorite.create(user_id:u.id,cost_id:deal.first.id)
      render :json => "Added #{deal.first.title} (#{id}) to favorites"
    end
  end

  def favorites
    u = User.find_or_create_by(slackid: params['user_id'])
    out = ""
    u.favorites.each{|x|out = out + "\n#{x.cost.title} – #{x.cost.code}"}
    render :json => out
  end

  def entries
    off = params['offset'].to_i || 0
    c = Entry.count
    more = c > 200 + off ? true : false
    render :json => {'entries'=>Entry.limit(200).offset(off),'more'=>more,'offset'=>off+200}.to_json
  end

  def costs
    render :json => Cost.pluck(:title,:code).to_json
  end

  def unfavorite
    u = User.find_or_create_by(slackid: params['user_id'])
    id = params['text']
    c = Cost.where(code:id).first
    if c.nil?
      render :json => "Deal not found"
    else
      Favorite.where(user_id:u.id,cost_id:c.id).destroy_all
      render :json => "Deal #{c.title} (#{id}) removed from favorites"
    end
  end

  def reset
    u = User.find_or_create_by(slackid: params['user_id'])
    tz = localtime(u.slackid)
    date = DateTime.now.in_time_zone(tz).strftime("%Y-%m-%d")
    u.entries.where(date:date).destroy_all
    render :json => "Day reset"
  end

  def add
    begin
      note = nil
      exp = params['text'].split(' ')
      bob_exp = exp.dup

      if TYPES.include?(bob_exp[0])
        # then we have one of those weird activity type things
        activity_type = bob_exp.shift
        kind = activity_type
      else
        kind = 'time'
      end

      deal_id = bob_exp.shift
      time =    bob_exp.shift.to_f
      date =    bob_exp[0]
      if parsed_date = Chronic.parse(date)
        # confusingly, if the date is like '08-23' and that date (August 23rd) has already occured this year, Chronic will parse it as the next year
        # So if today's date is August 25, 2017 and you do "Chronic.parse('08-23')" the result will be "2018-08-23" not "2017-08-23" as you might expect
        if(date.length < 6) # if no year was provided
          parsed_date = parsed_date.change(year: Date.today.year) # assume current year
        end
        bob_exp.shift
      end
      note = bob_exp.join(" ")

      if exp.length < 2 || !is_number?(time) || (!is_number?(deal_id) && !is_number?(date))
        render :json => "Please enter a code and an amount of time"
      elsif !is_number?(deal_id) && !TYPES.include?(deal_id.downcase)
        puts "deal_id, #{deal_id}"
        render :json => "Supported activity types are time, onsite, call, and vendor"
      else
        u = User.find_or_create_by(slackid: params['user_id'])
        u.name ||= realname(u.slackid)
        u.email ||= getemail(u.slackid)
        u.save!

        if(parsed_date)
          due = parsed_date
        else
          tz = localtime(u.slackid)
          due = DateTime.now.in_time_zone(tz)
          zone = ActiveSupport::TimeZone[tz]
          Chronic.time_class = zone
        end

        if note.include?('||')
          note.gsub!("||", "")
        end

        fancy_date = due.strftime("%Y-%m-%d")
        note = note.strip
        if time > 40
          render :json => "You can only add up to 40 hours at a time"
        else
          cst = Cost.where(code: deal_id).first
          if cst.nil?
            render :json => "Deal not found"
          else
            title = cst.title
            @entry = Entry.create(
              user_id: u.id,
              email: u.email,
              date: fancy_date,
              deal_id: deal_id,
              kind: kind,
              note: note,
              time: time,
              title: title,
              user_name: u.name
            )
            out = "Thanks! #{time} added to #{deal_id} (#{title}) for #{fancy_date}"
            out << " with note #{note}" unless note.nil? || note.empty?
            render :json => out
          end
        end
      end
    rescue => e
      puts e, e.backtrace
      render :json => "Sorry, didn't understand that"
    end
  end

  def newcost
    c = Cost.where(category:'cost center').pluck(:code).max
    Cost.create(title:params['text'],code:c+1,category:'cost center')
    render :json => "Added #{params['text']}, code #{c+1}"
  end

  def standup
    u = User.find_or_create_by(slackid: params['user_id'])

    tz = localtime(u.slackid)
    date = DateTime.now.in_time_zone(tz).strftime("%Y-%m-%d")

    out = ""
    ents = u.entries.where(date:date)
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
