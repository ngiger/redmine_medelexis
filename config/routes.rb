# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

#custom routes for this plugin
  resources :licenses
  match 'my/license', :to => 'license#gen_license', :via => 'get'
  match ':login/license', :to => 'license#gen_license', :via => 'get'
