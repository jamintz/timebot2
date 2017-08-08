class WeeksController < ApplicationController
  COMMENT_URL = "https://api.github.com/repos/demystdata"
      
  def index
    'Time tracking is fun!'
  end
  
  def week
    text = params['text']
    if text == ''
      out = "It is currently week #{wkdt(Time.now)}!"
    elsif text.length <= 2
      out = "Week #{text.to_i} is around #{text.to_i.weeks.since(Time.now.beginning_of_year).to_date}"
    else
      d = Chronic.parse(text)
      if d.nil?
        out = 'Unrecognized date'
      else
        out = "Date #{d.to_date} is week #{wkdt(d)}"
      end
    end
    render :json => out
  end
  
  def setkey
    user = params['user_id']
    text = params['text']
    
    ender :json => 'Please specify a key' unless text
    u = User.find_or_create_by(slackid:user)
    u.ghkey = text
    u.save!
    render :json => 'Saved'
  end
  
  def comment
    text = params['text'].split(' ')
    key = get_key(params['user_id'])
    
    unless key
      render :json => "Missing github key. Generate and add personal access token with repo access using '/setkey [token]'"
    end
    
    if text.empty?
      render :json => 'Uh oh, please specify an issue # and a comment'
    end
    
    num = text.shift
    
    unless numeric(num) && text.count >= 1
      render :json =>  'Oops, please specify an issue # and a comment'
    end
    
    comment = text.join(' ')
    url = COMMENT_URL+"/basin/issues/#{num}/comments?access_token=#{key}"
    
    resp = HTTParty.post(url,:body=>{:body=>comment}.to_json)
    
    if resp.code == 201
      render :json => 'Commented!'
    else 
      render :json => "Error #{resp.code}"
    end
  end
  
  def issue
    text = params['text'].split('//')
    key = get_key(params['user_id'])
          
    unless key
      render :json => "Missing github key. Generate and add personal access token with '/setkey [token]'"
    end
    
    title = text.first
    content = text.last
    
    render :json => 'Please add some text' if title.nil?
    url = COMMENT_URL+"/basin/issues?access_token=#{key}"
    
    resp = HTTParty.post(url,:body=>{:title=>title,:body=>content}.to_json)
    
    if resp.code == 201
      render :json => "Issue created at #{resp.parsed_response['url']}"
    else 
      render :json => "Error #{resp.code}"
    end
  end
    
  def numeric (str)
      Float(str) != nil rescue false
  end

  def wkdt tm
    tm.strftime('%W')
  end
  
  def get_key u
    u = User.where(slackid:u).first
    u.empty? ? nil : u.ghkey
  end
end
