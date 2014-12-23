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

class LicenseControllerTest < ActionController::TestCase
    ActiveRecord::Fixtures.create_fixtures(Redmine::Plugin.find(:redmine_medelexis).directory + '/test/fixtures/',
                            [
                             :contacts,
                             :contacts_projects,
                             :custom_fields,
                             :custom_fields_projects,
                             :custom_fields_roles,
                             :custom_fields_trackers,
                             :custom_values,
                             :invoice_lines,
                             :invoice_payments,
                             :invoices,
                             :issues,
                             :members,
                             :products,
                             :projects,
                             :roles,
                             :settings,
                             :tokens,
                             :trackers,
                             :users,
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

  def dump_invoice(inv)
    puts "invoice #{inv.id} #{inv.number}. total #{inv.calculate_amount.to_f.round(2)} from #{inv.custom_field_values}"
    puts "   dumpling lines"
    inv.lines.each{
      |line|
      puts "#{line.description} #{line.quantity.to_f.round(2)} #{line.price.to_f.round(2)}"
    }
  end

  def dump_issues(id)
    project = Project.find(id)
    puts "Project had #{project.issues.size} issues"
    project.issues.each {
      |issue|
      puts "issued #{issue.subject} #{issue.start_date} #{issue.updated_on} #{issue.custom_field_values}"
    }
  end

  test "verify invoicing with mustermann issues" do
    mustermann = Project.find(3)
    xxxSize= Project.all.size
    oldSize= Invoice.all.size
    stichtag = Date.today.end_of_year
    res = MedelexisInvoices.startInvoicing(stichtag)
    assert_not_nil res
    newSize= Invoice.all.size
    nrCreated = newSize -oldSize
    content = res.inspect.to_s
    assert (nrCreated == 1 ), "Must have created exactyl one. Not #{nrCreated}"
    inv = Invoice.last
    # dump_invoice(inv); dump_issues(res.first)
    assert ( inv.due_date == stichtag+30),   "Due date must be today + 30. But is #{inv.due_date} instead of #{stichtag+30} #{xxxSize}"
    assert ( inv.lines.size == 3 ),            "Invoice must have 3 lines. Not #{inv.lines.size}" # one item is TRIAL
    assert ( inv.calculate_amount < 10000.0 ), "Amount must be smaller than 10kFr. But is #{inv.calculate_amount.to_f.round(2)}"
  end

  test "verify invoicing today" do
    mustermann = Project.find(3)
    oldSize= Invoice.all.size
    stichtag = Date.today
    res = MedelexisInvoices.startInvoicing(stichtag)
    assert_not_nil res
    newSize= Invoice.all.size
    nrCreated = newSize -oldSize
    content = res.inspect.to_s
    assert (nrCreated == 1 ), "Must have created exactyl one. Not #{nrCreated}"
    inv = Invoice.last
    assert ( inv.due_date == stichtag+30),   "Due date must be today + 30. But is #{inv.due_date} instead of #{stichtag+30}"
    assert ( inv.lines.size == 3 ),            "Invoice must have 3 lines. Not #{inv.lines.size}" # one item is TRIAL
    assert ( inv.calculate_amount < 10000.0 ), "Amount must be smaller than 10kFr. But is #{inv.calculate_amount.to_f.round(2)}"
  end

  test "second invoicing may not produce a new invoice" do
    mustermann = Project.find(3)
    oldSize= Invoice.all.size
    stichtag = Date.today
    res = MedelexisInvoices.startInvoicing(stichtag)
    assert_not_nil res
    sizeAfterFirstRun= Invoice.all.size
    nrCreated = sizeAfterFirstRun -oldSize
    content = res.inspect.to_s
    assert (nrCreated == 1 ), "Must have created exactyl one. Not #{nrCreated}"
    inv = Invoice.last
    assert ( inv.due_date == stichtag+30),   "Due date must be today + 30. But is #{inv.due_date} instead of #{stichtag+30}"
    assert ( inv.lines.size == 3 ),            "Invoice must have 3 lines. Not #{inv.lines.size}" # one item is TRIAL
    assert ( inv.calculate_amount < 10000.0 ), "Amount must be smaller than 10kFr. But is #{inv.calculate_amount.to_f.round(2)}"
    res = MedelexisInvoices.startInvoicing(stichtag)
    assert_not_nil res
    sizeAfterSecondRun= Invoice.all.size
    assert_equal(sizeAfterFirstRun, sizeAfterSecondRun)
  end

  test "test findLastInvoiceDate" do
    assert_equal(nil, MedelexisInvoices.getDateOfLastInvoice(-1), 'an invalid project_id must return nil')
    assert_equal(Date.new(2014,11,15), MedelexisInvoices.getDateOfLastInvoice(Invoice.first.project_id))
  end

  test "check amount for invoicing again after 3 months" do
    mustermann = Project.find(3)
    Invoice.all.each{|x| x.delete}
    oldSize= Invoice.all.size
    stichtag = Date.today
    res = MedelexisInvoices.startInvoicing(stichtag)
    assert_not_nil res
    sizeAfterFirstRun= Invoice.all.size
    nrCreated = sizeAfterFirstRun -oldSize
    content = res.inspect.to_s
    assert (nrCreated == 1 ), "Must have created exactyl one. Not #{nrCreated}"
    inv = Invoice.last
    res = MedelexisInvoices.startInvoicing(stichtag + 3*31)
    assert_not_nil res
    sizeAfterSecondRun= Invoice.all.size
    assert_equal(sizeAfterFirstRun + 1, sizeAfterSecondRun)
    # dump_issues(mustermann); dump_invoice(inv)
    # Insure that we find the description of the product, not it's code
    nrFounds = inv.lines.find_all{|line| line.description.match(/Medelexis 3/i)}
    assert_equal(1, nrFounds.size)
    nrFounds = inv.lines.find_all{|line| line.description.match(/feature/)}
    assert_equal(0, nrFounds.size)

    # Insure that we find a partial payment
    nrFounds = inv.lines.find_all{|line| line.description.match(/ wird für 434 Tage verrechnet/i)}
    assert_equal(1, nrFounds.size)
    nrFounds = inv.lines.find_all{|line| line.description.match(/Faktor 1.19/i)}
    assert_equal(1, nrFounds.size)
    nrFounds = inv.lines.find_all{|line| line.description.match(/Faktor 0.77/i)}
    assert_equal(1, nrFounds.size)
    nrFounds = inv.lines.find_all{|line| line.description.match(/ wird für 280 Tage verrechnet/i)}
    assert_equal(1, nrFounds.size)
    nrFounds = inv.lines.find_all{|line| line.description.match(/ wird für 160 Tage verrechnet/i)}
    assert_equal(1, nrFounds.size)
    nrFounds = inv.lines.find_all{|line| line.description.match(/Faktor 0.44/i)}
    assert_equal(1, nrFounds.size)
    inv2 = Invoice.last
    msg =  "Amount of second invoice of #{inv2.calculate_amount.to_i} (#{stichtag + 3*31}) must be smaller than first invoice #{inv.calculate_amount.to_i} from (#{stichtag})"
    assert(inv2.calculate_amount.to_i < inv.calculate_amount.to_i, msg)
  end

end
