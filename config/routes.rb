Rails.application.routes.draw do
  
  
  post 'weeks/week'
  post 'weeks/setkey'
  post 'weeks/comment'
  post 'weeks/issue'
  
  get 'times/get'
  get 'times/standup'
  get 'times/totals'
  post 'times/add'
  post 'times/remove'
  get 'times/favorites'
  post 'times/save'
  get 'times/find'
  
  
end
