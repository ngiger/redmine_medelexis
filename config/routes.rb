# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

#custom routes for this plugin
  resources :licenses
  match 'my/license', :to => 'license#show', :via => 'get'
  match ':login/license', :to => 'license#show', :via => 'get', :render => :api

  get 'Rechnungslauf', :to => 'license#rechnungslauf'
  get '/license/rechnungen_erstellt', :to => 'license#rechnungen_erstellt'
  get 'Rechnungslauf', :to => 'license#rechnungslauf'
  post '/Rechnungslauf', :to => 'license#rechnungen_erstellt'
Redmine::Plugin.register :licenses do
  permission :rechnungslauf, :license => :rechnungslauf
end
