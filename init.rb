Redmine::Plugin.register :redmine_medelexis do
  name 'Redmine Medelexis plugin'
  author 'Niklaus Giger <niklaus.giger@member.fsf.org>'
  description 'Redmine plugin for the new configurator'
  version '0.2.4'
  url 'https://github.com/ngiger/redmine_medelexis'
  author_url 'http://www.giger-electronique.ch'
  settings :default => {'empty' => true}, :partial => 'settings/redmine_medelexis_settings'
#  requires_redmine_plugin :redmine_products, :version_or_higher => '1.1.0'
  requires_redmine_plugin :redmine_contacts, :version_or_higher => '3.2.17'
  requires_redmine_plugin :redmine_contacts_invoices, :version_or_higher => '3.1.4'
  menu :admin_menu, :licenses,
      {:controller => 'settings', :action => 'plugin', :id => "redmine_medelexis"},
       :caption => :label_medelexis, :param => :project_id
end
begin require 'pry'; rescue LoadError; end

where = File.expand_path(File.dirname(__FILE__))
# require "#{where}/lib/medelexis_hook_listener"
require 'redmine_medelexis'
