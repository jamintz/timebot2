Rails.application.routes.draw do
  
  post '/weeks/week'
  post '/weeks/setkey'
  post '/weeks/comment'
  post '/weeks/issue'
  
  post '/times/standup'
  post '/times/add'
  post '/times/unfavorite'
  post '/times/favorites'
  post '/times/save'
  post '/times/find'
  post '/times/newcost'
  post '/times/reset'
  post '/times/undo'
  
  get '/times/costs'
  get '/times/entries'
end
