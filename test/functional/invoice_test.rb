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
    puts "invoice #{last_invoice.id} #{last_invoice.number}. total #{last_invoice.calculate_amount.to_f.round(2)} from #{last_invoice.custom_field_values}"
    puts "   dumpling lines"
    last_invoice.lines.each{
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

  test "after invoicing getDateOfLastInvoice must bill correct number of days" do
    mustermann = Project.find(3)
    oldSize= Invoice.all.size
    invoice_since = Date.new(2099, 1, 1)
    stichtag = Date.new(2099, 2, 15)
    nrDay =  (stichtag - invoice_since).to_i # 45

    res = MedelexisInvoices.startInvoicing(stichtag, invoice_since)
    assert_not_nil res
    sizeAfterFirstRun= Invoice.all.size
    nrCreated = sizeAfterFirstRun -oldSize
    content = res.inspect.to_s
    assert (nrCreated == 1 ), "Must have created exactyl one. Not #{nrCreated}"
    assert_equal(stichtag, MedelexisInvoices.getDateOfLastInvoice(Invoice.first.project_id))
    Invoice.all.last.lines.each{ |line| puts line.description }
    assert_match(/wird für\s+45\s+Tage verrechnet/, Invoice.all.last.lines.first.description)
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
    last_invoice = Invoice.last
    # dump_invoice(inv); dump_issues(res.first)
    trial_issue = last_invoice.lines.find_all{|x| x.description if /gratis/i.match(x.description) }
    assert_equal 1, trial_issue.size,       "Invoice must have 1 free product. Not #{trial_issue.size}" # one item is TRIAL
    assert ( last_invoice.calculate_amount < 10000.0 ), "Amount must be smaller than 10kFr. But is #{last_invoice.calculate_amount.to_f.round(2)}"
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
    last_invoice = Invoice.last
    trial_issue = last_invoice.lines.find_all{|x| x.description if /gratis/i.match(x.description) }
    assert_equal 1, trial_issue.size,       "Invoice must have 1 free product. Not #{trial_issue.size}" # one item is TRIAL
    assert ( last_invoice.calculate_amount < 10000.0 ), "Amount must be smaller than 10kFr. But is #{last_invoice.calculate_amount.to_f.round(2)}"
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
    last_invoice = Invoice.last
    required_due_date = ((Time.now.to_date) + 31).to_time
    assert (last_invoice.due_date == required_due_date),   "Due date must be today + 31. But is #{last_invoice.due_date} instead of #{required_due_date}"
    trial_issue = last_invoice.lines.find_all{|x| x.description if /gratis/i.match(x.description) }
    assert_equal 1, trial_issue.size,       "Invoice must have 1 free product. Not #{trial_issue.size}" # one item is TRIAL
    assert ( last_invoice.calculate_amount < 10000.0 ), "Amount must be smaller than 10kFr. But is #{last_invoice.calculate_amount.to_f.round(2)}"
    res = MedelexisInvoices.startInvoicing(stichtag)
    assert_not_nil res
    sizeAfterSecondRun= Invoice.all.size
    assert_equal(sizeAfterFirstRun, sizeAfterSecondRun)
  end

  test "after invoicing getDateOfLastInvoice must return correct date" do
    mustermann = Project.find(3)
    oldSize= Invoice.all.size
    stichtag = Date.today - 5
    res = MedelexisInvoices.startInvoicing(stichtag)
    assert_not_nil res
    sizeAfterFirstRun= Invoice.all.size
    nrCreated = sizeAfterFirstRun -oldSize
    content = res.inspect.to_s
    assert (nrCreated == 1 ), "Must have created exactyl one. Not #{nrCreated}"
    assert_equal(stichtag, MedelexisInvoices.getDateOfLastInvoice(Invoice.first.project_id))
  end

  test "test findLastInvoiceDate" do
    assert_equal(nil, MedelexisInvoices.getDateOfLastInvoice(-1), 'an invalid project_id must return nil')
    assert_equal(Date.new(2014,11,15), MedelexisInvoices.getDateOfLastInvoice(Invoice.first.project_id))
  end

  test "check amount for invoicing again after 3 months" do
    mustermann = Project.find(3)
    Invoice.all.each{|x| x.delete}
    oldSize= Invoice.all.size
    abo_start = Date.new(2014, 1, 1)
    date_first_invoice = Date.new(2014, 12, 15)
    res = MedelexisInvoices.startInvoicing(date_first_invoice, abo_start)
    assert_not_nil res
    sizeAfterFirstRun= Invoice.all.size
    nrCreated = sizeAfterFirstRun -oldSize
    content = res.inspect.to_s
    assert (nrCreated == 1 ), "Must have created exactyl one. Not #{nrCreated}"
    first_invoice = Invoice.first
    nr_days = 3*31
    date_second_invoice = date_first_invoice + nr_days
    res = MedelexisInvoices.startInvoicing(date_second_invoice, date_first_invoice)
    assert_not_nil res
    sizeAfterSecondRun= Invoice.all.size
    assert_equal(sizeAfterFirstRun + 1, sizeAfterSecondRun)

    # Insure that we find the description of the product, not it's code
    last_invoice = Invoice.last
    nrFounds = last_invoice.lines.find_all{|line| line.description.match(/Medelexis 3/i)}
    assert_equal(1, nrFounds.size)
    nrFounds = last_invoice.lines.find_all{|line| line.description.match(/feature/)}
    assert_equal(1, nrFounds.size)

    assert( first_invoice.lines.find{|line| line.description.match(/Medelexis.+ wird für 348 Tage verrechnet/i) }, 'correct day for Medelexis')
    assert( first_invoice.lines.find{|line| line.description.match(/cancelled.+ wird für 280 Tage verrechnet/i) }, 'correct days for cancelled item')
    assert( first_invoice.lines.find{|line| line.description.match(/gratis/i) }, 'TRIAL must be gratis')

    assert( last_invoice.lines.find{|line| line.description.match(/Medelexis.+ wird für #{nr_days} Tage verrechnet/i) }, 'correct day for Medelexis')
    assert_nil( last_invoice.lines.find{|line| line.description.match(/cancelled.+ wird für 280 Tage verrechnet/i) }, 'cancelled item may not appear again')
    assert( last_invoice.lines.find{|line| line.description.match(/gratis/i) }, 'TRIAL must be gratis')
    assert_nil( last_invoice.lines.find{|line| line.description.match(/Grundpreis von 0.0/i) }, 'prices with 0 should not appear')

    msg =  "Amount of second invoice of #{last_invoice.calculate_amount.to_i} (#{date_second_invoice}) must be smaller than first invoice #{first_invoice.calculate_amount.to_i} from (#{date_first_invoice})"
    assert(last_invoice.calculate_amount.to_i < first_invoice.calculate_amount.to_i, msg)
  end

  test "verify that project KeinVerrechnung does not get an invoicing" do
    project = Project.find(4)
    oldSize= Invoice.all.size
    stichtag = Date.today.end_of_year
    assert_equal(nil, MedelexisInvoices.invoice_for_project(project.id, stichtag))
    newSize= Invoice.all.size
    nrCreated = newSize -oldSize
    assert_equal 0, nrCreated, "May not create an invoice #{nrCreated} newSize #{newSize} #{oldSize}"
  end

end
