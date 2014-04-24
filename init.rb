Redmine::Plugin.register :redmine_medelexis do
  name 'Redmine Medelexis plugin'
  author 'Niklaus Giger <niklaus.giger@member.fsf.org>'
  description 'Redmine plugin for the new configurator'
  version '0.0.4'
  url 'https://github.com/ngiger/redmine_medelexis'
  author_url 'http://www.giger-electronique.ch'
  settings :default => {'empty' => true}, :partial => 'settings/redmine_medelexis_settings'
#   }, :partial => 'settings/invoices/invoices'

end

where = File.expand_path(File.dirname(__FILE__))
# require "#{where}/lib/medelexis_hook_listener"
require 'redmine_medelexis'
