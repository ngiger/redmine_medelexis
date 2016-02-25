# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

#custom routes for this plugin
  resources :licenses
  match 'my/license', :to => 'license#show', :via => 'get'
  match ':login/license', :to => 'license#show', :via => 'get', :render => :api

  get  '/medelexis/rechnungslauf', :to => 'medelexis#rechnungslauf'
  post '/medelexis/rechnungslauf', :to => 'medelexis#rechnungslauf'

  get  '/medelexis/alle_rechnungen', :to => 'medelexis#alle_rechnungen'

  get  '/medelexis/correct_invoice_lines', :to => 'medelexis#correct_invoice_lines'
  post '/medelexis/correct_invoice_lines', :to => 'medelexis#correct_invoice_lines'
  get  '/medelexis/confirm_invoice_lines', :to => 'medelexis#confirm_invoice_lines'
  post '/medelexis/confirm_invoice_lines', :to => 'medelexis#confirm_invoice_lines'
  get  '/medelexis/changed_invoice_lines', :to => 'medelexis#changed_invoice_lines'

  match ':login/license', :to => 'license#show', :via => 'get', :render => :api

  Redmine::Plugin.register :medelexis do
    permission :rechnungslauf, :medelexis => :rechnungslauf
  end if false
