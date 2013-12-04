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
    ActiveRecord::Fixtures.create_fixtures(Redmine::Plugin.find(:redmine_medelexis).directory + '/test/fixtures/',
                            [:settings,
                             :issues,
                             :users,
                             :contacts,
                             :contacts_projects,
                             :members,
                             :roles,
                             :projects,
                             :tokens,
                             :trackers,
                             :custom_fields,
                             :custom_fields_trackers,
                             :custom_values,
                             ])

  def setup
    Setting.rest_api_enabled = '1'
    FileUtils.rm_rf(File.join(Dir.tmpdir, 'redmine_medelexis'))
    User.current = nil
    RedmineMedelexis::TestCase.prepare
    RedmineMedelexis::TestCase.plugin_fixtures :redmine_medelexis, :all
  end

    def get_signed_xml_path(username)
    signed_xml = File.join(Dir.tmpdir, 'redmine_medelexis', "#{username}_signed.xml")
  end
    RunAll = false
  def verify_license_file(username)
    signed_xml = get_signed_xml_path(username)
    assert(File.exists?(signed_xml))
    content = IO.read(signed_xml)
    assert_match('<medelexisLicense xmlns', content)
    assert_match("<customerId>#{username}</customerId>", content)
    assert_match("projectId=\"3\"", content)
    assert_match('<numberOfStations', content)
    assert_match('<numberOfPractitioners', content)
    assert_match('<Signature xmlns', content)
    assert_match(Medelexis_License_Regexp, content)
  end
if RunAll
  test "GET /my/license.xml invalid api_key" do
    login_as('admin')
    @parameters = {:key => 'invalid_key' }
    get '/my/license.xml', @parameters
    assert_response 404
  end

  test "PUT /my/license.xml invalid api_key" do
    login_as('admin')
    @parameters = {:key => 'invalid_key' }
    put '/my/license.xml', @parameters
    assert_response 404
  end

  test "GET /my/license.xml with good api key for bad user" do
    login_as('mmustermann')
    api_key = get_api_key('wfeconnector')
    get  "/my/license.xml", { 'key' => api_key }
    assert_response 404
  end
end
  test "GET /api/license.xml by api_key" do
    username = 'mmustermann'    
    get "/api/license.xml", { 'key' => get_api_key(username) }
    assert(username != User.current.login)
   # require 'pry'; binding.pry
    assert_response :success
    verify_license_file(username)
  end
  
  test "GET /my/license.xml" do
    username = 'mmustermann'    
    login_as(username)
    assert_equal(username, User.current.login)
    get "/api/license.xml" #, { 'key' => get_api_key(username) }
   # require 'pry'; binding.pry
    assert_equal(username, User.current.login)
    assert_response :success
    verify_license_file(username)
  end

    test 'Get redmine-test' do
    # Test that a request allows the username and password for HTTP BASIC
    #
    # @param [Symbol] http_method the HTTP method for request (:get, :post, :put, :delete)
    # @param [String] url the request url
    # @param [optional, Hash] parameters additional request parameters
    # @param [optional, Hash] options additional options
    # @option options [Symbol] :success_code Successful response code (:success)
    # @option options [Symbol] :failure_code Failure response code (:unauthorized)
   # def self.should_allow_http_basic_auth_with_username_and_password(http_method, url, parameters={}, options={})
    #Redmine::ApiTest::Base.should_allow_http_basic_auth_with_username_and_password(:get, '/my/license.xml')
    Redmine::ApiTest::Base.should_allow_http_basic_auth_with_username_and_password(:get, '/my/license.xml')
    end
  test 'Get redmine-test with apyi' do
    Redmine::ApiTest::Base.should_allow_http_basic_auth_with_key(:get, '/my/license.xml')
  end
  test "GET /my/license.xml for active user" do
    username = 'mmustermann'
    pwd ='12345678'
    change_user_password(username, pwd)
#    login_as(username)
    log_user(username, pwd)
    pp  User.find_by_login(username)
    @request.session[:user_id] = User.find_by_login(username)
    assert_equal(username, User.current.login)
    get "/my/license.xml"
#    assert_equal(username, User.current.login)
    assert_response :success
    verify_license_file(username)
  end

if RunAll
  test "GET /mmustermann/license.xml as non non-admin for myself" do
    username = 'mmustermann'    
    login_as(username)
    get "/#{username}/license.xml"
    assert_response 500
  end

  test "GET /mmustermann/license.xml as admin" do
    username = 'mmustermann'    
    login_as('admin')
    get "/#{username}/license.xml"
    assert_response :success
  end

  test "GET /mmustermann/license.xml as admin and via API-Key" do
    username = 'mmustermann'    
    api_key = get_api_key('wfeconnector')
    @parameters = { 'key' => api_key }
    login_as('admin')
    get "/#{username}/license.xml", @parameters 
    assert_response :success
  end

  test "GET /admin/license.xml as mmustermann" do
    username = 'mmustermann'    
    login_as(username)
    res = get '/admin/license.xml', nil
    assert_response 404
  end

  test 'access to admin and my/page as admin' do
    login_as('admin')
    assert('admin', User.current.login)
    get '/my/page'
    assert_response :success
    get '/admin'
    assert_response :success
  end

  test 'access to admin and my/page as mmustermann' do
    username = 'mmustermann'    
    login_as(username)
    assert_equal 'mmustermann', User.current.login
    get '/my/page'
    assert_response :success
    get '/admin'
    assert_response 403 # forbidden
  end

  test "auth by api_key and verify content of generated license.xml" do
    username = 'mmustermann'    
    login_as(username)
    signed_xml = get_signed_xml_path(username)
    FileUtils.rm_f(signed_xml)               
    get "/my/license?key=#{User.find_by_login(username).api_key}.xml"
    assert_response :success
    verify_license_file(username)
    content = IO.read(signed_xml)
    assert     ( /id="ch.medelexis.application.feature"/ .match(content) )
    assert_nil ( /id="ch.elexis.base.textplugin.feature"/.match(content) )
  end

end
end
