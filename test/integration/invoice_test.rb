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
                             :invoices,
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

  test "should route to post" do
    assert_routing '/medelexis/rechnungslauf', {controller: "medelexis", action: "rechnungslauf"}
  end

  test "login and go to rechnungslauf" do
    # login via https
    https!
    get "/login"
    assert_response :success
    get "/admin"
    assert_equal "/admin", path
    get "/settings/plugin/redmine_medelexis"
    assert_response 302
    assert_equal "/settings/plugin/redmine_medelexis", path
    get '/medelexis/rechnungslauf'
    skip "don't know how to test the form to start a rechnungslauf"
  end

  def teardown
    Setting.rest_api_enabled = '0'
    Setting.login_required = '0'
  end
  
end
