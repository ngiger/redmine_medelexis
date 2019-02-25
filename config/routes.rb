# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

#custom routes for this plugin
  resources :licenses
  match 'my/license.xml',     :to => 'license#show', :via => 'get', :render => :html
  match 'my/license.html',    :to => 'license#show', :via => 'get', :render => :html
  match 'my/license',         :to => 'license#show', :via => 'get', :render => :plain
  match ':login/license.xml', :to => 'license#show', :via => 'get', :render => :html
  match ':login/license.html',:to => 'license#show', :via => 'get', :render => :html
  match ':login/license',     :to => 'license#show', :via => 'get', :render => :plain
  match 'unauthorized',       :to => 'license#unauthorized', :via => 'get', :render => :html

  get  '/medelexis/rechnungslauf', :to => 'medelexis#rechnungslauf'
  post '/medelexis/rechnungslauf', :to => 'medelexis#rechnungslauf'

  get  '/medelexis/alle_rechnungen', :to => 'medelexis#alle_rechnungen'
  get  '/medelexis/alle_kunden',     :to => 'medelexis#alle_kunden'

  get  '/medelexis/correct_invoice_lines', :to => 'medelexis#correct_invoice_lines'
  post '/medelexis/correct_invoice_lines', :to => 'medelexis#correct_invoice_lines'
  get  '/medelexis/confirm_invoice_lines', :to => 'medelexis#confirm_invoice_lines'
  post '/medelexis/confirm_invoice_lines', :to => 'medelexis#confirm_invoice_lines'
  get  '/medelexis/changed_invoice_lines', :to => 'medelexis#changed_invoice_lines'


  Redmine::Plugin.register :medelexis do
    permission :rechnungslauf, :medelexis => :rechnungslauf
  end if false
