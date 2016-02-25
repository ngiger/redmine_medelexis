# encoding: utf-8
#
# This file is a part of Redmine Invoices (redmine_contacts_invoices) plugin,
# invoicing plugin for Redmine
#
# Copyright (C) 2011-2014 Kirill Bezrukov
# http://www.redminecrm.com/
#
# redmine_contacts_invoices is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# redmine_contacts_invoices is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with redmine_contacts_invoices.  If not, see <http://www.gnu.org/licenses/>.

require File.expand_path('../../test_helper', __FILE__)

class RoutingTest < ActionController::IntegrationTest

  test "invoices" do
    assert_routing({ :path => "/medelexis/rechnungslauf", :method => :get },
                   { :controller => "medelexis", :action => "rechnungslauf" })
  end

  test "invoices_lines" do
    assert_routing({ :path => "/medelexis/correct_invoice_lines", :method => :get },
                   { :controller => "medelexis", :action => "correct_invoice_lines" })
  end

  test "invoices_lines_confirm" do
    assert_routing({ :path => "/medelexis/confirm_invoice_lines", :method => :get },
                   { :controller => "medelexis", :action => "confirm_invoice_lines" })
  end

  test "invoices_lines_changed" do
    assert_routing({ :path => "/medelexis/changed_invoice_lines", :method => :get },
                   { :controller => "medelexis", :action => "changed_invoice_lines" })
  end

end
