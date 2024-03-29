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

class InvoiceControllerTest < ActionController::TestCase
  ID_mustermann = 3
    ActiveRecord::FixtureSet.create_fixtures(Redmine::Plugin.find(:redmine_medelexis).directory + '/test/fixtures/',
                            [
                             :contacts,
                             :contacts_projects,
                             :custom_fields,
                             :custom_fields_projects,
                             :custom_fields_roles,
                             :custom_fields_trackers,
                             :custom_values,
                             :enabled_modules,
                             :enumerations,
                             :invoice_lines,
                             :invoice_payments,
                             :invoices,
                             :issues,
                             :issue_statuses,
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
    @mustermann = Project.find(ID_mustermann)
    @all_project_issues = Issue.where(project_id: ID_mustermann, tracker_id: RedmineMedelexis::Tracker_Is_Service)
    @trial_issue = @all_project_issues.find{|x| x.custom_field_values.first.to_s.eql?('TRIAL') }
    @end_of_year = Date.today.end_of_year
    change_start_date(@trial_issue,  @end_of_year - 25)
  end

  def teardown
    Setting.rest_api_enabled = '0'
    Setting.login_required = '0'
  end

  def dump_invoice(invoice)
    puts "invoice #{invoice.id} #{invoice.number}. total #{invoice.calculate_amount.to_f.round(2)} from #{invoice.custom_field_values}"
    puts invoice.description
    invoice.lines.each_with_index{
      |line, id|
      puts "   #{id}: #{line.price.to_f.round(2)} #{line.description} #{line.quantity.to_f.round(2)} "
    }
    nil
  end

  def dump_issues(id)
    project = Project.find(id)
    puts "Project had #{project.issues.size} issues"
    project.issues.each {
      |issue|
      puts "issued #{issue.subject} #{issue.start_date} #{issue.updated_on} #{issue.custom_field_values}"
    }
    nil
  end

  def set_issue_state(issue, state = 'TRIAL')
    issue.custom_field_values.first.value = state
    issue.save_custom_field_values
    issue.save!
  end

  test "verify invoicing today" do
    oldSize= Invoice.all.size
    change_start_date(@all_project_issues.find{|x| /text/.match(x.subject)},  @end_of_year - 25)
    res = MedelexisInvoices.startInvoicing(@end_of_year)
    dump_invoice(Invoice.last)
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

  test "after invoicing getDateOfLastInvoice must bill correct number of days" do
    oldSize= Invoice.all.size
    invoice_since = Date.new(2015, 1, 1)
    stichtag = Date.new(2015, 2, 15)
    nrDay =  (stichtag - invoice_since).to_i # 45

    res = MedelexisInvoices.startInvoicing(stichtag, invoice_since)
    assert_not_nil res
    sizeAfterFirstRun= Invoice.all.size
    nrCreated = sizeAfterFirstRun -oldSize
    content = res.inspect.to_s
    assert (nrCreated == 1 ), "Must have created exactyl one. Not #{nrCreated}"
    assert_equal(stichtag, MedelexisInvoices.getDateOfLastInvoice(Invoice.first.project_id, stichtag))
    assert_match(/wird für\s+45\s+Tage verrechnet/, Invoice.all.last.lines.last.description)
  end

  test "verify invoicing with mustermann issues" do
    oldSize= Invoice.all.size
    res = MedelexisInvoices.startInvoicing(@end_of_year)
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

  test "second invoicing may not produce a new invoice" do
    oldSize= Invoice.all.size
    stichtag = Date.today
    res = MedelexisInvoices.startInvoicing(stichtag)
    assert_not_nil res
    sizeAfterFirstRun= Invoice.all.size
    nrCreated = sizeAfterFirstRun -oldSize
    content = res.inspect.to_s
    assert (nrCreated == 1 ), "Must have created exactyl one. Not #{nrCreated}"
    last_invoice = Invoice.last
    required_due_date = (Date.today.next_month + 1)
    stichtag = Date.today
    assert( (required_due_date.to_date - last_invoice.due_date.to_date).to_i <= 1, 'Date must be about a month from now')
    trial_issue = last_invoice.lines.find_all{|x| x.description if /gratis/i.match(x.description) }
    assert_equal 1, trial_issue.size,       "Invoice must have 1 free product. Not #{trial_issue.size}" # one item is TRIAL
    assert ( last_invoice.calculate_amount < 10000.0 ), "Amount must be smaller than 10kFr. But is #{last_invoice.calculate_amount.to_f.round(2)}"
    res = MedelexisInvoices.startInvoicing(stichtag)
    assert_not_nil res
    sizeAfterSecondRun= Invoice.all.size
    assert_equal(sizeAfterFirstRun, sizeAfterSecondRun, 'must have some number of invoices after first and second run')
  end

  test "invoicing with due_date before stichtag may not be included in a invoice" do
    oldSize = Invoice.all.size
    stichtag = Date.today
    concerned_issues = Issue.all.find_all{|x| x.due_date && x.due_date > stichtag}
    assert_equal(1, concerned_issues.size)
    unique_title =  'Darf nicht mehr verrechnet werden'
    issue = concerned_issues.first
    issue.start_date = stichtag - 300
    issue.due_date = stichtag-1
    issue.description = unique_title
    issue.save!
    res = MedelexisInvoices.startInvoicing(stichtag)
    assert_not_nil res
    assert_equal(oldSize + 1,  Invoice.all.size, 'Must have produced an invoice')
    assert_nil( Invoice.last.lines.to_s.index(unique_title), "May not include #{unique_title}")
  end

  test "invoicing with due_date before stichtag, but updated_on later may not may not be included in a invoice" do
    oldSize = Invoice.all.size
    stichtag = Date.today
    concerned_issues = Issue.all.find_all{|x| x.due_date && x.due_date > stichtag}
    assert_equal(1, concerned_issues.size)
    unique_title =  'Darf nicht mehr verrechnet werden'
    issue = concerned_issues.first
    issue.updated_on = stichtag + 300
    issue.start_date = stichtag - 300
    issue.due_date = stichtag - 1
    issue.description = unique_title
    issue.save!
    res = MedelexisInvoices.startInvoicing(stichtag)
    assert_not_nil res
    assert_equal(oldSize + 1,  Invoice.all.size, 'Must have produced an invoice')
    assert_nil( Invoice.last.lines.to_s.index(unique_title), "May not include #{unique_title}")
  end

  test "after invoicing getDateOfLastInvoice must return correct date" do
    oldSize= Invoice.all.size
    stichtag = Date.today - 5
    res = MedelexisInvoices.startInvoicing(stichtag)
    assert_not_nil res
    sizeAfterFirstRun= Invoice.all.size
    nrCreated = sizeAfterFirstRun -oldSize
    content = res.inspect.to_s
    assert (nrCreated == 1 ), "Must have created exactyl one. Not #{nrCreated}"
    assert_equal(stichtag, MedelexisInvoices.getDateOfLastInvoice(Invoice.first.project_id, stichtag))
  end

  test "test findLastInvoiceDate" do
    assert_nil( MedelexisInvoices.getDateOfLastInvoice(-1), 'an invalid project_id must return nil')
    assert_nil( MedelexisInvoices.getDateOfLastInvoice(Invoice.first.project_id))
  end

  test "check amount for invoicing again after 3 months" do
    Invoice.all.each{|x| x.delete}
    oldSize= Invoice.all.size
    abo_start = Date.new(2014, 1, 1)
    date_first_invoice = Date.new(2014, 12, 15)
    change_start_date(@trial_issue,  date_first_invoice - 10)
    set_issue_state(@trial_issue, 'TRIAL')
    res = MedelexisInvoices.startInvoicing(date_first_invoice, abo_start)
    assert_not_nil res
    first_invoice = Invoice.first
    dump_invoice(Invoice.first) # if $VERBOSE
    sizeAfterFirstRun= Invoice.all.size
    nrCreated = sizeAfterFirstRun -oldSize
    content = res.inspect.to_s
    assert (nrCreated == 1 ), "Must have created exactyl one. Not #{nrCreated}"
    nr_days = 3*31
    change_start_date(Issue.find_by_subject('ch.elexis.added_later.feature'), Date.new(2014, 9, 30))
    date_second_invoice = date_first_invoice + nr_days
    res = MedelexisInvoices.startInvoicing(date_second_invoice, date_first_invoice)
    second_invoice = Invoice.last
    assert_not_nil res
    sizeAfterSecondRun= Invoice.all.size
    assert_equal(sizeAfterFirstRun + 1, sizeAfterSecondRun, 'must have added an invoice')
    # dump_issues(mustermann); dump_invoice(second_invoice)
    # Ensure that we find the description of the product, not it's code
    nrFounds = first_invoice.lines.find_all{|line| line.description.match(/Medelexis 3/i)}
    assert_equal(1, nrFounds.size, 'first_invoice must contain Medelexis 3')
    nrFounds = first_invoice.lines.find_all{|line| line.description.match(/feature/)}.reject{|x| / gratis /i.match(x.description) }
    assert_equal(0, nrFounds.size, 'first_invoice must not contain any feature')

    # Cancelled items must be paid for the whole year!
    nrFounds = first_invoice.lines.find_all{|line| line.description.match(/ wird für 348 Tage verrechnet/i)}
    assert_equal(1, nrFounds.size, 'first_invoice must contain 348 Tage')
    nrFounds = first_invoice.lines.find_all{|line| line.description.match(/ wird für 280 Tage verrechnet/i)}
    assert_equal(0, nrFounds.size, 'first_invoice must contain 280 Tage')
    nrFounds = first_invoice.lines.find_all{|line| line.description.match(/ wird für 160 Tage verrechnet/i)}
    assert_equal(0, nrFounds.size, 'first_invoice may not contain 160 Tage')

    # Ensure that we find the description of the product, not it's code
    nrFounds = second_invoice.lines.find_all{|line| line.description.match(/Medelexis 3/i)}
    assert_equal(1, nrFounds.size, 'second_invoice must contain Medelexis 3')
    nrFounds = second_invoice.lines.find_all{|line| line.description.match(/feature/i)}
    assert(1<= nrFounds.size, 'second_invoice must contain a feature')
    assert( first_invoice.lines.find{|line| line.description.match(/Medelexis.+ wird für 348 Tage verrechnet/i) }, 'first_invoice: correct day for Medelexis')
    assert_nil( first_invoice.lines.find{|line| line.description.match(/cancelled.+ wird für 348 Tage verrechnet/i) }, 'first_invoice: correct days for cancelled item')
    assert( first_invoice.lines.find{|line| line.description.match(/gratis/i) }, 'first_invoice: TRIAL must be gratis')
    assert_nil( first_invoice.lines.find{|line| line.description.match(/added.+/i) }, 'first_invoice: later added item may not appear')

    assert( second_invoice.lines.find{|line| line.description.match(/Medelexis.+ wird für #{nr_days} Tage verrechnet/i) }, 'second_invoice: correct day for Medelexis')
    dump_invoice(second_invoice) if $VERBOSE
    assert( second_invoice.lines.find{|line| line.description.match(/added.+wird für.+93.+Tage/i) }, 'second_invoice: correct days for added item')
    assert_nil( second_invoice.lines.find{|line| line.description.match(/cancelled.+/i) }, 'second_invoice: cancelled item may not appear again')
    assert( second_invoice.lines.find{|line| line.description.match(/gratis/i) }, 'second_invoice: TRIAL must be gratis')
    # assert_nil( second_invoice.lines.find{|line| line.description.match(/Grundpreis von 0.0/i) }, 'second_invoice: prices with 0 should not appear')

    msg =  "Amount of second invoice of #{second_invoice.calculate_amount.to_i} (#{date_second_invoice}) must be smaller than first invoice #{first_invoice.calculate_amount.to_i} from (#{date_first_invoice})"
    assert(second_invoice.calculate_amount.to_i < first_invoice.calculate_amount.to_i, msg)
  end

  test "verify that project KeinVerrechnung does not get an invoicing" do
    project = Project.find(4)
    oldSize= Invoice.all.size
    assert_nil( MedelexisInvoices.invoice_for_project(project.id, @end_of_year))
    newSize= Invoice.all.size
    nrCreated = newSize -oldSize
    assert_equal 0, nrCreated, "May not create an invoice #{nrCreated} newSize #{newSize} #{oldSize}"
  end

  test "verify that project invoice_for_project works when passing a name" do
    project = Project.find(4)
    oldSize= Invoice.all.size
    assert_nil( MedelexisInvoices.invoice_for_project(project.identifier, @end_of_year))
  end

  test "second invoicing may not produce a new invoice even if since given" do
    oldSize= Invoice.all.size
    stichtag = Date.today
    invoice_since = stichtag-365
    res = MedelexisInvoices.startInvoicing(stichtag, invoice_since)
    assert_not_nil res
    sizeAfterFirstRun= Invoice.all.size
    nrCreated = sizeAfterFirstRun -oldSize
    content = res.inspect.to_s
    assert (nrCreated == 1 ), "Must have created exactyl one. Not #{nrCreated}"
    last_invoice = Invoice.last
    required_due_date = (Date.today.next_month + 1)
    diff = (last_invoice.due_date.to_date - required_due_date.to_date)
    assert (diff <= 1),   "Due date must be about a month from now. But is #{last_invoice.due_date} instead of #{required_due_date}"
    trial_issue = last_invoice.lines.find_all{|x| x.description if /gratis/i.match(x.description) }
    assert_equal 1, trial_issue.size,       "Invoice must have 1 free product. Not #{trial_issue.size}" # one item is TRIAL
    assert ( last_invoice.calculate_amount < 10000.0 ), "Amount must be smaller than 10kFr. But is #{last_invoice.calculate_amount.to_f.round(2)}"
    res = MedelexisInvoices.startInvoicing(stichtag, invoice_since)
    assert_not_nil res
    sizeAfterSecondRun= Invoice.all.size
    assert_equal(sizeAfterFirstRun, sizeAfterSecondRun, 'must have some number of invoices after first and second run')
  end

  test "Must match correct invoice stichtag" do
    assert_equal('2015-12-31', MedelexisInvoices::DurationMatcher.match(MedelexisInvoices::Example_2015_1)[1])
    assert_equal('2016-12-31', MedelexisInvoices::DurationMatcher.match(MedelexisInvoices::Example_2016_1)[1])
  end

  def create_buchhaltung
    buchhaltung = Issue.new(:project =>  Project.find(ID_mustermann),
                             :subject => 'ch.elexis.buchhaltung.feature',
                             :author => User.find(3),
                             :priority => IssuePriority.find(2),
                             :tracker => Tracker.find(4),
                             :start_date => Date.new(2014, 06, 01),
                             :status_id => 1,
                             :description => "Buchhaltung niklaus"
                            )
    buchhaltung.custom_field_values = { IssueCustomField.first.id.to_s => 'LICENSED'}
    buchhaltung.save!
  end

  test 'check issue ranges updated_on after due_date and stichtag' do
    licensed = Issue.find(6)
    start_of_year = Date.new(2016, 1,  1)
    end_of_year   = Date.new(2016,12, 31)
    updated       = Date.new(2016, 4, 15)
    due_date      = start_of_year
    assert_equal('LICENSED', licensed.custom_field_values.first.to_s)
    licensed.start_date = start_of_year -365
    licensed.due_date   = nil
    licensed.updated_on = nil
    licensed.save!
    licensed
    assert_equal(true, MedelexisInvoices.issueDateInRange?(licensed, end_of_year, start_of_year), 'before cancelling it must be in the range')

    cancel_string = 'CANCELLED'.force_encoding('utf-8')
    licensed.custom_field_values.first.value  = cancel_string
    licensed.due_date = start_of_year
    licensed.updated_on = end_of_year + 300
    licensed.save!
    assert_equal(cancel_string, licensed.custom_field_values.first.to_s)
    assert_equal(false, MedelexisInvoices.issueDateInRange?(licensed, end_of_year, start_of_year), 'after cancelling it may not be in the range')

    licensed.due_date = updated
    licensed.save!
    assert_equal(cancel_string, licensed.custom_field_values.first.to_s)
    assert_equal(true, MedelexisInvoices.issueDateInRange?(licensed, end_of_year, start_of_year), 'after cancelling inside the range it must be in the range')
  end

  test 'check issue ranges' do
    licensed = Issue.find(6)
    test_day = Date.new(2014, 6, 15)
    days_before = test_day -10
    days_after = test_day + 19
    month_before = test_day -33
    month_after = test_day + 33
    assert_equal('LICENSED', licensed.custom_field_values.first.to_s)

    licensed.start_date = test_day

    assert_equal(true, MedelexisInvoices.issueDateInRange?(licensed, days_after, days_before), 'start_date is between two days 1')
    assert_equal(true, MedelexisInvoices.issueDateInRange?(licensed, month_after, month_before), 'start_date is between two month 2')
    assert_equal(true, MedelexisInvoices.issueDateInRange?(licensed, month_after, days_after), 'start_date is between two days 3')

    cancelled = Issue.find(4)
    assert_equal('CANCELLED', cancelled.custom_field_values.first.to_s)
    cancelled.start_date = test_day
    test_day_2 = Date.new(2015, 6, 15)
    cancelled.due_date = test_day_2

    assert_equal(true, MedelexisInvoices.issueDateInRange?(cancelled, test_day_2 + 1, days_before), 'cancelled start_date is between two days')
    assert_equal(true,  MedelexisInvoices.issueDateInRange?(cancelled, month_after, days_after), 'cancelled start_date is between two days')
    assert_equal(true, MedelexisInvoices.issueDateInRange?(cancelled, month_after, month_before), 'cancelled start_date is between two month')

    assert_equal(false, MedelexisInvoices.issueDateInRange?(cancelled, days_before, month_before), 'cancelled start_date is between two days')

    assert_equal(false, MedelexisInvoices.issueDateInRange?(cancelled, month_before, days_before), 'cancelled start_date is between two days')
    assert_equal(false, MedelexisInvoices.issueDateInRange?(licensed, month_before, days_before), 'start_date is between two days 4')
    assert_equal(false, MedelexisInvoices.issueDateInRange?(licensed, days_after, month_after), 'start_date is between two days 5')
  end

  test "check invoice issues added after first invoice only once" do
    Invoice.all.each{|x| x.delete}
    abo_start = Date.new(2014, 1, 1)
    invoice_stichtag = Date.new(2014, 12, 31)
    test_issue = @all_project_issues.find{|x| /ch.elexis.added_later.feature/.match(x.subject) }
    change_start_date(test_issue,  invoice_stichtag + 25)
    assert( test_issue.start_date > invoice_stichtag, 'last issued must not be contained in first invoice')
    res = MedelexisInvoices.startInvoicing(invoice_stichtag, abo_start)
    first_invoice = Invoice.first
    # dump_invoice(first_invoice);
    assert_not_nil res
    sizeAfterFirstRun= Invoice.all.size
    change_start_date(test_issue, invoice_stichtag -90 )
    res = MedelexisInvoices.startInvoicing(invoice_stichtag, abo_start)
    assert_not_nil res
    assert_equal(sizeAfterFirstRun + 1, Invoice.all.size, 'Must have added an invoice')
    second_invoice = Invoice.last
    dump_invoice(second_invoice);
    assert_nil(first_invoice.lines.find{|line| line.description.match(/ADDED LATER/i)},  'Must have ADDED LATER item')
    assert_nil( second_invoice.lines.find{|line| line.description.match(/added.+wird für.+76.+Tage/i) }, 'second_invoice: Do not invoice added item')

    msg =  "Amount of second invoice of #{second_invoice.calculate_amount.to_i} must be smaller than first invoice #{first_invoice.calculate_amount.to_i} from (#{invoice_stichtag})"
    assert(second_invoice.calculate_amount.to_i < first_invoice.calculate_amount.to_i, msg)

    assert_nil( second_invoice.lines.find{|line| line.description.match(/Medelexis.+Tage verrechnet/i) }, 'second_invoice: Do not invoice Medelexis')
    assert_nil( second_invoice.lines.find{|line| line.description.match(/gratis/i) }, 'second_invoice: TRIAL must be gratis')
    assert(second_invoice.lines.find{|line| line.description.match(/ADDED LATER/i)},  'Must have ADDED LATER item')

    res = MedelexisInvoices.startInvoicing(invoice_stichtag, abo_start)
    assert_not_nil res
    assert_equal(sizeAfterFirstRun + 1, Invoice.all.size, 'Must have added the invoice only once')
  end

  test "get_lines must return correct array" do
    lines = MedelexisInvoices.get_lines('ADDED buchhaltung FEATURE')
    assert_kind_of(Array, lines)
    assert_kind_of(String, lines.first)
  end

  test "changed_lines must return correct array" do
    changed = 'Changed Name'
    MedelexisInvoices.startInvoicing(Date.new(2014, 12, 31), Date.new(2014, 1, 1))
    changed_lines =  MedelexisInvoices.change_line_items('ADDED buchhaltung FEATURE', changed)
    assert_equal([2], changed_lines)
    assert_match(/#{changed}/, InvoiceLine.find(2).description)

    changed_lines =  MedelexisInvoices.change_line_items('NOT_TO_BE_FOUND', changed)
    assert_equal([], changed_lines)
  end

  test "check invoice don't add a line when cancelled after less than a month" do
    days_ahead = 120
    days_before = 90
    cancelled_date = Date.today - 25
    abo_start = Date.today - days_before
    issue = Issue.find_by_subject('ch.elexis.cancelled.feature')
    issue.due_date= RedmineMedelexis::EwigesAblaufdatum
    change_start_date(issue, cancelled_date)
    oldSize= Invoice.all.size
    res = MedelexisInvoices.startInvoicing(Date.today + days_ahead, abo_start)
    invoice = Invoice.last
    assert_not_nil res
    dump_invoice(invoice)
    canncelled_items = invoice.lines.find_all{|line| line.description.match(/cancelled/i) }
    assert_equal(0, canncelled_items.size, 'cancelled item may not appear')
  end

  test "check invoice is taxed" do
    assert_equal 0.0, ContactsSetting.default_tax
    Setting.plugin_redmine_crm['default_tax'] = 8.0
    assert_equal 8.0, ContactsSetting.default_tax
    Invoice.all.each{|x| x.delete}
    oldSize= Invoice.all.size
    abo_start = Date.new(2014, 1, 1)
    invoice_stichtag = Date.new(2014, 12, 31)
    res = MedelexisInvoices.startInvoicing(invoice_stichtag, abo_start)
    first_invoice = Invoice.first
    dump_invoice(first_invoice);
    assert_not_nil res
    assert_equal(5, first_invoice.lines.size, 'must have 5 line')
    assert_not_equal(910, first_invoice.lines.find{|line| /Medelexis 3/.match line.description}.price.to_i, 'Medelexis 3 price must be != 910')
    assert_equal(first_invoice.lines.size, first_invoice.lines.collect{|line| line.tax}.size, 'each line must be taxed')
  end

  test "Invoicing must invoice correctly issued marked Gratis in a previous invoice" do
    project_id = Project.find(ID_mustermann)
    Invoice.all.each{|x| x.delete}
    abo_start = Date.today.beginning_of_year - 3.years
    date_first_invoice = Date.today.beginning_of_year - 2.years
    date_second_invoice = Date.today.end_of_year.to_date - 2.years
    Issue.last.start_date = date_first_invoice < 15
    change_start_date(@trial_issue,  date_first_invoice - 25)
    res = MedelexisInvoices.startInvoicing(date_first_invoice, abo_start)
    first_invoice = Invoice.first
    sizeAfterFirstRun = Invoice.all.size
    dump_invoice(first_invoice);
    assert_not_nil res
    RedmineMedelexis.convertExpiredTrial2License
    res = MedelexisInvoices.startInvoicing(date_second_invoice, date_first_invoice)
    assert_not_nil res
    second_invoice = Invoice.last
    dump_invoice(second_invoice);
    sizeAfterSecondRun= Invoice.all.size
    assert_equal(sizeAfterFirstRun + 1, sizeAfterSecondRun, 'Must have added an invoice')
    assert_equal(0, second_invoice.lines.find_all{|x| /gratis/i.match(x.description)}.size, 'Must invoice previously marked Gratis item')
    assert_nil( second_invoice.lines.find{|line| line.description.match(/added.+wird für.+76.+Tage/i) }, 'second_invoice: Do not invoice added item')
  end

  test 'HauptKontakt must be correct' do
    project = Project.find(ID_mustermann)
    assert_equal(3, project.contacts.size, 'Mustermann must have 3 contacts')
    contact = RedmineMedelexis.getHauptkontakt(project.id)
    assert_equal('Max', contact.first_name, 'HauptKontakt must be Max')
    assert_equal('Mustermann', contact.last_name, 'HauptKontakt must be Mustermann')
  end

end
