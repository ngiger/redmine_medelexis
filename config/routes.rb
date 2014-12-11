# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

#custom routes for this plugin
  resources :licenses
  match 'my/license', :to => 'license#show', :via => 'get'
  match ':login/license', :to => 'license#show', :via => 'get', :render => :api

  get 'Rechnungslauf', :to => 'license#rechnungslauf'
