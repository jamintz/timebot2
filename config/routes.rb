Rails.application.routes.draw do
  
  post '/weeks/week'
  post '/weeks/setkey'
  post '/weeks/comment'
  post '/weeks/issue'
  
  post '/times/get'
  post '/times/standup'
  post '/times/totals'
  post '/times/add'
  post '/times/remove'
  post '/times/favorites'
  post '/times/save'
  post '/times/find'
  
  
end
