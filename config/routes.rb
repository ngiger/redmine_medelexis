# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

#custom routes for this plugin
  resources :licenses
if false
#    match 'users/current/license', :to => 'license#gen_license_xml', :via => 'get', :login => 'current'
#    match 'license/:login/license', :to => 'license#gen_license_xml', :via => 'get'
    match 'my/license', :to => 'license#gen_license_xml_via_api', :via => 'get', :login => 'current'
#    match 'my/license/:api_key', :to => 'license#gen_license_xml_via_api', :via => 'get', :login => 'current'
#    match ':login/license', :to => 'license#gen_license_xml', :via => 'get'
else
# had problme  match 'my/license.xml', :to => 'license#gen_license_xml_via_api', :via => 'get', :login => 'current'
  match 'my/license', :to => 'license#gen_license_xml', :via => 'get'
  match 'api/license', :to => 'license#gen_license_xml_via_api', :via => 'get', :login => 'current'
  match ':login/license', :to => 'license#gen_license_xml', :via => 'get', :login => 'current'
end

#  match 'api/my/license', :to => 'license#gen_license_xml_via_api', :via => 'get'
#http://0.0.0.0:30001/my/license?e631d4560a13047970cc2ba4a95519782bdd4106.xml