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

class Redmine::ApiTest::LicenseTest < ActionController::TestCase
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
    @controller = LicenseController.new
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

  def verify_license_xml_content(content, username)
    assert_match('<medelexisLicense xmlns', content)
    assert_match("<customerId>#{username}</customerId>", content)
    assert_match("projectId=\"3\"", content)
    assert_match('<numberOfStations', content)
    assert_match('<numberOfPractitioners', content)
    assert_match('<Signature xmlns', content)
    assert_match(Medelexis_License_Regexp, content)
  end

  test "verify that I got no license for an invalid user" do
    username = 'admin'
    user = User.find_by_login(username)
    res = RedmineMedelexis.license_info_for_user(user)
    assert_nil res
  end
  
  test "verify that I got no license for an nil user" do
    res = RedmineMedelexis.license_info_for_user(nil)
    assert_nil res
  end
  
  test "verify expired trial not in license" do
    username = 'mmustermann'
    user = User.find_by_login(username)
    res = RedmineMedelexis.license_info_for_user(user)
    assert_not_nil res
    assert_nil ( /"ch.elexis.base.textplugin.feature"/.match(res.inspect.to_s) )
  end
  
  test "verify license valid user" do
    username = 'mmustermann'
    user = User.find_by_login(username)
    res = RedmineMedelexis.license_info_for_user(user)
    assert_not_nil res
    content = res.inspect.to_s
    assert     ( /#{username}/.match(content) )
    assert     ( /#{RedmineMedelexis.get_api_key(username)}/.match(content) )
    assert     ( /Praxis Dr. Mustermann/.match(content) )
    assert     ( /"ch.medelexis.application.feature"/ .match(content) )
  end

  test "verify license.xml content of a valid user" do
    username = 'mmustermann'
    user = User.find_by_login(username)
    info = RedmineMedelexis.license_info_for_user(user)
    xml  = RedmineMedelexis.xml_content(info)
    assert_not_nil xml
    assert     ( /#{username}/.match(xml) )
    assert     ( /#{RedmineMedelexis.get_api_key(username)}/.match(xml) )
    assert     ( /Praxis Dr. Mustermann/.match(xml) )
#    assert     ( /"ch.medelexis.application.feature"/ .match(xml) )
    verify_license_xml_content(xml, username)
  end


end
