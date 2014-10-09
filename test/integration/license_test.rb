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
require File.expand_path('../../test_helper', __FILE__)

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
    Setting.login_required = '1'
    FileUtils.rm_rf(File.join(Dir.tmpdir, 'redmine_medelexis'))
    User.current = nil
    RedmineMedelexis::TestCase.prepare
    RedmineMedelexis::TestCase.plugin_fixtures :redmine_medelexis, :all
  end

  def teardown
    Setting.rest_api_enabled = '0'
    Setting.login_required = '0'
  end
  
  def get_signed_xml_path(username)
    signed_xml = File.join(Dir.tmpdir, 'redmine_medelexis', "#{username}_signed.xml")
  end
  def verify_license_file(username)
    signed_xml = get_signed_xml_path(username)
    pp signed_xml
    assert(File.exists?(signed_xml))
    content = IO.read(signed_xml)
    assert_match('<medelexisLicense xmlns', content)
    assert_match("<customerId>#{username}</customerId>", content)
    assert_match("<projectId>3", content)
    assert_match('<numberOfStations', content)
    assert_match('<numberOfPractitioners', content)
    assert_match('<Signature xmlns', content)
    assert_match(Medelexis_License_Regexp, content)
  end
  
#  Redmine::ApiTest::Base.should_allow_api_authentication(:get, "/my/license.xml") # now has only 4 errors
  test "GET /my/license.xml by api_key" do
    username = 'mustermann'    
    res = get "/my/license.xml", { 'key' => RedmineMedelexis.get_api_key(username) }
    assert_response :success
  end

  test "GET /my/license.xml with good api key for bad user" do
    api_key = RedmineMedelexis.get_api_key('wfeconnector')
    res = get  "/my/license.xml", { 'key' => api_key }
    assert res != :success
  end

  test "GET /my/license.xml invalid api_key" do
    @parameters = {:key => 'invalid_key' }
    res = get '/my/license.xml', @parameters
    assert res != :success
  end

  test "PUT /my/license.xml invalid api_key" do
    @parameters = {:key => 'invalid_key' }
    res = put '/my/license.xml', @parameters
    assert res != :success
  end
  
 test "GET /mustermann/license as non non-admin for myself" do
    username = 'mustermann'  
    login_as(username)
    get "/mustermann/license"
    assert_response :success
  end

  test "GET /my/license as non non-admin for myself" do
    username = 'mustermann'
    login_as(username)
    get "/my/license"
    assert_response :success
    puts response.to_s
    puts 888
  end

  test "GET /mustermann/license as admin" do
    username = 'admin'  
    login_as(username)
    res = get "/mustermann/license"
    assert_response :success
    assert_template 'license/show'
  end

  test "auth by api_key and verify content of generated license.xml" do
    username = 'mustermann'    
    login_as(username)
    signed_xml = get_signed_xml_path(username)
    FileUtils.rm_f(signed_xml)               
    get "/my/license.xml?key=#{User.find_by_login(username).api_key}"
    assert_response :success
    verify_license_file(username)
    content = IO.read(signed_xml)
    assert     ( /id="ch.medelexis.application.feature"/ .match(content) )
    assert_nil ( /id="ch.elexis.base.textplugin.feature"/.match(content) )
    assert ( /id="ch.elexis.cancelled.feature" licenseType="CANCELLED"/.match(content) )
  end
  
  test "admin calls /my/license" do
    username = 'admin'
    login_as(username)
    signed_xml = get_signed_xml_path(username)
    FileUtils.rm_f(signed_xml)               
    res = get "/my/license.xml"
    assert res != :success
  end
end
