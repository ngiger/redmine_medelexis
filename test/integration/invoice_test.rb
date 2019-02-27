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


class Redmine::InvoiceTest < Redmine::IntegrationTest
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
    user = User.where(admin: true).first
    user.email_address = EmailAddress.create!(:user_id => user.id, :address => 'another@somenet.foo', :is_default => true)
    user.password, user.password_confirmation = "my_password"; user.save!
    Setting.rest_api_enabled = '1'
    Setting.login_required = '1'
    FileUtils.rm_rf(File.join(Dir.tmpdir, 'redmine_medelexis'))
    User.current = nil
    RedmineMedelexis::TestCase.prepare
    RedmineMedelexis::TestCase.plugin_fixtures :redmine_medelexis, :all
  end

  test "should route to rechnungslauf" do
    assert_routing '/medelexis/rechnungslauf', {controller: "medelexis", action: "rechnungslauf"}
  end
 if false
   puts "Omitting some test that require an api license" # TODO::

  def test_should_rename_invoice_lines
    login_as_admin
    get "/medelexis/correct_invoice_lines"
    abo_start = Date.new(2014, 1, 1)
    invoice_stichtag = Date.new(2014, 12, 31)

    assert_response :success
    post "/medelexis/correct_invoice_lines", :search_invoice_lines => { :invoice_since => abo_start, :release_date => invoice_stichtag, :project_to_invoice => 3}

    post"/medelexis/correct_invoice_lines", :create => { :invoice_since => abo_start, :release_date => invoice_stichtag, :project_to_invoice => 'abba'}
  end

  def test_should_create_invoice_test
    assert_difference('Invoice.count') do
      get "/medelexis/rechnungslauf"
      assert_response :success
      assert_template ["medelexis/rechnungslauf", 'layouts/base']
      # okay till here
      post :rechnungslauf, {:invoice_since => abo_start, :release_date => invoice_stichtag, :project_to_invoice => 'abba'}
    end
  end

  test "login and go to rechnungslauf" do
    get "/login"
    assert_response :success
    post "/login", :login => 'admin', :password => 'my_password'
    assert_response :success
    get "/admin"
    assert_equal "/admin", path
    get "/settings/plugin/redmine_medelexis"
    assert_response :success
    assert_equal "/settings/plugin/redmine_medelexis", path
    assert_response :success
    get '/medelexis/rechnungslauf'
  end

  def login_as_admin
    https!
 end
    get "/login"
    assert_response :success
    post "/login", :login => 'admin', :password => 'my_password'
    assert_response :success
  end

  def teardown
    Setting.rest_api_enabled = '0'
    Setting.login_required = '0'
  end

end
