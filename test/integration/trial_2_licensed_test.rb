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
                            [
                             :contacts,
                             :contacts_projects,
                             :custom_fields,
                             :custom_fields_trackers,
                             :custom_values,
                             :enumerations,
                             :issue_statuses,
                             :issues,
                             :members,
                             :projects,
                             :projects_trackers,
                             :roles,
                             :settings,
                             :tokens,
                             :trackers,
                             :users,
                             ])
  def setup
    Setting.rest_api_enabled = '1'
    Setting.login_required = '1'
    RedmineMedelexis::TestCase.prepare
    RedmineMedelexis::TestCase.plugin_fixtures :redmine_medelexis, :all
  end

  def teardown
    Setting.rest_api_enabled = '0'
    Setting.login_required = '0'
  end
  
  test "verify convertExpiredTrial2License" do
    assert_equal('LICENSED', Issue.find(1).custom_field_values.first.value)
    assert_equal('TRIAL', Issue.find(2).custom_field_values.first.value)
    res = RedmineMedelexis.convertExpiredTrial2License
    assert_equal 1, res.size
    assert_equal 1, Journal.all.size
    assert_equal 2, Journal.last.journalized_id
    assert_equal 'Issue', Journal.last.journalized_type
    assert /TRIAL/.match(Journal.last.notes)
  end
  
end
