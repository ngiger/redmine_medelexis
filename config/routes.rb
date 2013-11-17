# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

#custom routes for this plugin
  resources :licenses
  match 'license/:login/gen_license_jar', :to => 'license#gen_license_xml', :via => 'get'
