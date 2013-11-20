# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

#custom routes for this plugin
  resources :licenses
  match 'users/current/license', :to => 'license#gen_license_xml', :via => 'get'
  match 'license/:login/license', :to => 'license#gen_license_xml', :via => 'get'
  match 'my/license', :to => 'license#gen_license_xml', :via => 'get'
  match ':login/license', :to => 'license#gen_license_xml', :via => 'get'
