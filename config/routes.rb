# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

#custom routes for this plugin
  resources :licenses
  match 'users/current/license', :to => 'license#gen_license_xml', :via => 'get', :login => 'current'
  match 'license/:login/license', :to => 'license#gen_license_xml', :via => 'get'
  match 'my/license', :to => 'license#gen_license_xml_via_api', :via => 'get', :login => 'current'
  match 'my/license/:api_key', :to => 'license#gen_license_xml_via_api', :via => 'get', :login => 'current'
  match ':login/license', :to => 'license#gen_license_xml', :via => 'get'
