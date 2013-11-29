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
    RedmineMedelexis::TestCase.prepare
    RedmineMedelexis::TestCase.plugin_fixtures :redmine_medelexis, :all
  end
  
   test "auth by api_key and verify content of generated license.xml" do
    signed_xml = File.join(Dir.tmpdir, 'redmine_medelexis', 'mmustermann_signed.xml')
    FileUtils.rm_f(signed_xml)                           
    get "/my/license.xml?key=#{User.find_by_login('mmustermann').api_key}"
    assert_response :success
    assert File.exists?(signed_xml)
    content = IO.read(signed_xml)
    assert_match('<medelexisLicense xmlns', content)
    assert_match('<customerId>mmustermann</customerId>', content)
    assert_match('<numberOfStations>0</numberOfStations>', content)
    assert_match('<numberOfPractitioners>1</numberOfPractitioners>', content)
    assert_match('<Signature xmlns', content)    
    assert_match(Medelexis_License_Regexp, content)
    assert_match('id="ch.medelexis.application.feature"', content)
    assert_match('id="ch.elexis.base.textplugin.feature"', content)
   end if false

  test "GET /my/license.xml invalid api_key" do
    login_as('admin')
    @parameters = {:key => 'invalid_key' }
    put '/my/license/12345.xml', @parameters
    assert_response 404
  end

  test "GET /my/license.xml with good api key for bad user" do
    api_key = get_api_key('wfeconnector')
    url_with_api = "/my/license/#{api_key}.xml"
    @parameters = { 'key' => api_key }
    res = get url_with_api, @parameters
    assert_response 404
  end

 test "GET /mmustermann/license.xml as mmustermann" do
    login_as('mmustermann')
    res = get '/mmustermann/license.xml', nil
    assert_response :success
  end
  
  test "GET /mmustermann/license.xml as admin" do
    login_as('admin')
    res = get '/mmustermann/license.xml', nil
    assert_response :success
  end
  
  test "GET /admin/license.xml as mmustermann" do
    login_as('mmustermann')
    res = get '/admin/license.xml', nil
    assert_response 404
  end
  
  test 'access to admin and my/page as admin' do
    login_as('admin')
    assert_equal 'admin', User.current.login
    get '/my/page'
    assert_response :success
    get '/admin'
    assert_response :success
  end
  
  test 'access to admin and my/page as mmustermann' do
    login_as('mmustermann')
    assert_equal 'mmustermann', User.current.login
    get '/my/page'
    assert_response :success
    get '/admin'
    assert_response 403 # forbidden
  end

end
