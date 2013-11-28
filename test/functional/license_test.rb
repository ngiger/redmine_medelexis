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

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class Redmine::ApiTest::LicenseTest < ActionController::IntegrationTest
#  include Devise::TestHelpers
    ActiveRecord::Fixtures.create_fixtures(Redmine::Plugin.find(:redmine_medelexis).directory + '/test/fixtures/', 
                            [:settings,
                             :users,
                             :contacts,
                             :roles,
                             :projects,
                             :tokens,
                             ])

  def setup
    Setting.rest_api_enabled = '1'
    RedmineMedelexis::TestCase.prepare
    RedmineMedelexis::TestCase.plugin_fixtures :redmine_medelexis, :all
  end
  
  test "GET /my/license.xml invalid api_key" do
    bypass_login('admin')
    @parameters = {:key => 'invalid_key' }
    put '/my/license/12345.xml', @parameters
    assert_response 404
  end

  test "GET /my/license.xml with good api key" do
    bypass_login('mmustermann')
    api_key = get_api_key('wfeconnector')
    url_with_api = "/my/license/#{api_key}.xml"
    @parameters = { 'key' => api_key }
    res = get url_with_api, @parameters
    assert_response :success
  end
  
  test "GET /mmustermann/license.xml as mmustermann" do
    bypass_login('mmustermann')
    res = get '/mmustermann/license.xml', nil
    assert_response :success
  end
  
  test "GET /mmustermann/license.xml as admin" do
    bypass_login('admin')
    res = get '/mmustermann/license.xml', nil
    assert_response :success
  end
  
  test "GET /admin/license.xml as mmustermann" do
    bypass_login('mmustermann')
    res = get '/admin/license.xml', nil
    assert_response 404
  end
  
  test 'access to admin and my/page as admin' do
    bypass_login('admin')
    assert_equal 'admin', User.current.login
    get '/my/page'
    assert_response :success
    get '/admin'
    assert_response :success
  end
  
  test 'access to admin and my/page as mmustermann' do
    bypass_login('mmustermann')
    assert_equal 'mmustermann', User.current.login
    get '/my/page'
    assert_response :success
    get '/admin'
    assert_response 403 # forbidden
  end
  
end
