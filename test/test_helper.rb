# encoding: utf-8
#
# This file is a part of Redmine CRM (redmine_contacts) plugin,
# customer relationship management plugin for Redmine
#
# Copyright (C) 2011-2013 Kirill Bezrukov
# http://www.redminecrm.com/
#
# redmine_contacts is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# redmine_contacts is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with redmine_contacts.  If not, see <http://www.gnu.org/licenses/>.
require File.expand_path(File.dirname(__FILE__) + '/../../../test/test_helper')

def fixture_files_path
  "#{File.expand_path('..',__FILE__)}/fixtures/files/"
end

def bypass_login(user_login)
  clear_password = 'dummy'
  user = User.find_by_login(user_login)
  calculated =  User.hash_password("#{user.salt}#{User.hash_password clear_password}")
  user.hashed_password =  calculated
  user.save    
  post "/login", username: user_login, password:  clear_password
  https!(false)
  assert_equal user_login, User.current.login
  # puts "User #{User.current} hashed_password #{User.current.hashed_password}"; $stdout.flush
end

def get_api_key(username)
  user = User.find_by_login(username)
  token = Token.find_by_user_id(user.id)
  token = Token.where("user_id = #{user.id} and action == 'api'")
  assert_equal(1, token.size)
  api_key = token[0].value
end

# Engines::Testing.set_fixture_path

class RedmineMedelexis::TestCase
  include ActionDispatch::TestProcess
  def self.prepare
    Role.find(1, 2, 3).each do |r| 
      r.permissions << :view_contacts
      r.permissions << :view_invoices
      r.permissions << :view_expenses      
      r.save
    end
    Role.find(1, 2).each do |r| 
      r.permissions << :edit_contacts
      r.permissions << :edit_invoices
      r.permissions << :edit_expenses      
      r.permissions << :delete_invoices
      r.permissions << :delete_expenses      
      r.save
    end

    Project.find(1, 2, 3).each do |project| 
      EnabledModule.create(:project => project, :name => 'contacts_module')
      EnabledModule.create(:project => project, :name => 'contacts_invoices')
      EnabledModule.create(:project => project, :name => 'contacts_expenses')      
    end
  end
  
  def self.plugin_fixtures(plugin, *fixture_names)
    plugin_fixture_path = "#{Redmine::Plugin.find(plugin).directory}/test/fixtures"
    if fixture_names.first == :all
      fixture_names = Dir["#{plugin_fixture_path}/**/*.{yml}"]
      fixture_names.map! { |f| f[(plugin_fixture_path.size + 1)..-5] }
    else
      fixture_names = fixture_names.flatten.map { |n| n.to_s }
    end
    
    if false
    ActiveRecord::Fixtures.create_fixtures(Redmine::Plugin.find(:redmine_contacts).directory + '/test/fixtures/', 
                            [:contacts,
                             :contacts_projects,
                             :contacts_issues,
                             :deals,
                             :notes,
                             :roles,
                             :enabled_modules,
                             :tags,
                             :taggings,
                             :contacts_queries])   

    ActiveRecord::Fixtures.create_fixtures(Redmine::Plugin.find(:redmine_contacts_invoices).directory + '/test/fixtures/', 
                          [:invoices,
                           :invoice_lines])
    ActiveRecord::Fixtures.create_fixtures(Redmine::Plugin.find(:redmine_contacts_helpdesk).directory + '/test/fixtures/', 
                          [:tags,
                           :deals])
    end
  end

  def uploaded_test_file(name, mime)
    ActionController::TestUploadedFile.new(ActiveSupport::TestCase.fixture_path + "/files/#{name}", mime, true)
  end

  if false
  def self.is_arrays_equal(a1, a2)
    (a1 - a2) - (a2 - a1) == []
  end

  def self.prepare
    # User 2 Manager (role 1) in project 1, email jsmith@somenet.foo
    # User 3 Developer (role 2) in project 1


    Role.find(1, 2, 3, 4).each do |r|
      r.permissions << :view_contacts
      r.save
    end

    Role.find(1, 2).each do |r|
      #user_2, user_3
      r.permissions << :add_contacts
      r.save
    end

    Array(Role.find(1)).each do |r|
      #user_2
      r.permissions << :add_deals
      r.permissions << :save_contacts_queries
      r.save
    end

    Role.find(1, 2).each do |r|
      r.permissions << :edit_contacts
      r.save
    end
    Role.find(1, 2, 3).each do |r|
      r.permissions << :view_deals
      r.save
    end

    Role.find(2) do |r|
      r.permissions << :edit_deals
      r.save
    end

    Role.find(1, 2).each do |r|
      r.permissions << :manage_public_contacts_queries
      r.save
    end

    Project.find(1, 2, 3, 4, 5).each do |project|
      EnabledModule.create(:project => project, :name => 'contacts')
    end
  end
  end
end
