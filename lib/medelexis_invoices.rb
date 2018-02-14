#!/usr/bin/env ruby
#encoding: utf-8

File.expand_path('../redmine_medelexis', __FILE__)
require 'medelexis_helpers'

class Project
  def keineVerrechnung
    field = CustomField.all.find{|x| /Keine Verrechnung/i.match(x.name)}
    return false unless field
    return false unless custom = custom_value_for(field.id)
    custom.value.to_i > 0 ? true : false
  end
  def nrDoctors
    field = CustomField.all.find{|x| /# Ärzte/i.match(x.name)}
    if (field && custom_value_for(field))
      custom_value_for(field).value.to_i
    else
      ''
    end
  end
  def nrStations
    field = CustomField.all.find{|x| /# Stationen/i.match(x.name)}
    if (field && custom_value_for(field))
      custom_value_for(field).value.to_i
    else
      ''
    end
  end
  def systemProperties
    field = CustomField.all.find{|x| /systemProperties/i.match(x.name)}
    if (field && custom_value_for(field))
      custom_value_for(field).value
    else
      ''
    end
  end
  def kundenstatus
    custom_field_values # forces evaluation. Avoids an error in test/functional
    field = CustomField.all.find{|x| /Kundenstatus/i.match(x.name)}
    if (field && custom_value_for(field))
      custom_value_for(field).value
    else
      ''
    end
  end
end

module MedelexisInvoices
  OnlyFirst   = false # for debugging purposes
  AboSubject  = "Rechnung für Abonnement Medelexis"
  # Before we had Rechnung mit Stichtag vom 2015-12-31 für 2 Ärzte.
  Example_2015_1 = "Rechnung mit Stichtag vom 2015-12-31 für 2 Ärzte.
Multiplikator für abonnierte Features ist 1.7."
  Example_2016_1 = "Rechnung mit Stichtag vom 2016-12-31 für 2 Ärzte.
Multiplikator für abonnierte Features ist 1.7.
Verrechnet werden Leistungen vom 2016-01-01 bis 2016-12-31."
  Duration = "Verrechnet werden Leistungen vom %s bis %s."
  DurationMatcher = /Stichtag vom (\d{4}-\d{2}-\d{2})/ # This must always match all old examples!
  START_COMMON_LINE_INFO = '. Grundpreis'
  # urse
  DiscountMap = { 1 => 1,
                  2 => 1.7,
                  3 => 2.3,
                  4 => 2.9,
                  5 => 3.5,
                  6 => 4}
  MaxDiscount = 0.5
  DatumsFormat = '%Y-%m-%d'
  TrialDays    = 31

  def self.getStichtag(invoice)
    return nil unless invoice.subject.eql?(AboSubject)
    m = DurationMatcher.match(invoice.description)
    string_date = m[1] if m
    unless m && string_date
      RedmineMedelexis.log_to_system "Unable to get stictag for invoice #{invoice.id} had invoice_date #{m} for #{invoice.subject}"
      raise "#{invoice.description} of invoice #{invoice.id} does not match 'Stichtag vom|bis <stichtag>'" unless m && string_date
      return nil
    end
    puts "invoice #{invoice.id} had invoice_date #{string_date} for #{invoice.subject}" if $VERBOSE
    Date.parse(string_date)
  end

  def self.issueDateInRange?(issue, stich_tag, invoice_since)
    return false if (stich_tag <= invoice_since)
    # raise "Stichtag #{stichtag} muss > sein als #{invoice_since} (Startag) " if (stich_tag <= invoice_since)
    status = issue.custom_field_values.first.value
    info = "#{issue.id} #{status}: #{invoice_since}-#{stich_tag} for issue #{issue.start_date} - #{issue.updated_on}. Due #{issue.due_date}"
    return false if status.eql?('CANCELLED') && issue.due_date && (issue.due_date.to_date - issue.start_date.to_date).to_i <= TrialDays
    if status.eql?('CANCELLED') || status.eql?('EXPIRED')
      return false unless issue.due_date
      if (issue.due_date <= invoice_since) || (issue.start_date > stich_tag)
        return false
      end
    end
    if (issue.start_date < stich_tag)
      return true
    else
      return false
    end
  end

  def self.findAllOpenServicesForProjectID(project_id,  stich_tag = Date.today.end_of_year.to_date, invoice_since = nil)
    invoice_since  ||= Date.today.beginning_of_year
    puts "findAllOpenServicesForProjectID #{stich_tag.inspect} #{invoice_since.inspect}" if $VERBOSE
    return [] if (stich_tag.to_date - invoice_since.to_date).to_i < 0
    all_project_issues = Issue.where(project_id: project_id, tracker_id: RedmineMedelexis::Tracker_Is_Service)
    invoices = Invoice.where(project_id: project_id).reject{ |invoice| getStichtag(invoice) == nil || getStichtag(invoice) < invoice_since }
    return all_project_issues unless invoices
    last_invoices = getLastInvoicesForProject(project_id, stich_tag)
    has_invoices_for_stichtag = last_invoices && last_invoices.size > 0
    return all_project_issues unless has_invoices_for_stichtag
    last_invoices = last_invoices
    open_issues = []
    core_name = Product.first.name
    all_invoices_lines = invoices.collect{|invoice| invoice.lines.collect{|line| line.description }}.flatten
    all_project_issues.each do |issue|
      if !issueDateInRange?(issue, stich_tag, invoice_since)
        puts "Skipping #{issue.id} #{issue.subject} with #{issue.start_date}" if $VERBOSE
      else
        product = getProduct(issue)
        if !product
          puts "Skip no product for #{issue.id} #{issue.subject}" if $VERBOSE
        elsif product.price.to_f.to_i == 0
          puts "Skip price #{issue.id} #{issue.subject}" if $VERBOSE
        elsif has_invoices_for_stichtag &&
            product.name.eql?(core_name) &&
            all_invoices_lines.find_all{|line| /#{core_name}/i.match(line)  }.size > 0
            puts "Skip #{core_name} line #{issue.id}" if $VERBOSE
        elsif has_invoices_for_stichtag
          lines = all_invoices_lines.find_all{|line| line.index(product.name) }
          if /gratis/i.match(lines.first)
            puts "Add gratis product #{issue.id} #{product.name}" if $VERBOSE
          else
            puts "Skip matched product #{issue.id} #{product.name}" if $VERBOSE
            next
          end if lines.size > 0
          open_issues << issue
        else
          puts "Adding #{issue.id} #{product.name}" if $VERBOSE
          open_issues << issue
        end
      end
    end
    open_issues
  end

  def self.getLastInvoicesForProject(project_id, stichtag)
    projects = Project.where(id: project_id )
    unless projects.size > 0
      puts "getLastInvoicesForProject no projects found for #{project_id}" if $VERBOSE
      return nil
    end
    project = projects.first
    invoices = Invoice.where(project_id: project.id).reject{ |invoice| getStichtag(invoice) == nil }
    unless invoices.size > 0
      puts "getLastInvoicesForProject no invoices found for #{project_id}" if $VERBOSE
      return nil
    end
    invoices.find_all{ |x| getStichtag(x).eql?(stichtag)}
  end

  def self.getDateOfLastInvoice(project_id, stichtag = Date.today.to_datetime.end_of_year)
    last = getLastInvoicesForProject(project_id, stichtag)
    return nil unless last && last.size > 0
    lastDate = getStichtag(last.first)
    puts "getDateOfLastInvoice lastDate for #{project_id}/#{stichtag} was #{lastDate}" if $VERBOSE
    lastDate
  end

  def self.getDaysOfYearFactor(issue, invoice_since, day2invoice = Date.today.to_datetime.end_of_year)
    status = issue.custom_field_values.first.value
    daysThisYear = (day2invoice.end_of_year.to_date - day2invoice.beginning_of_year.to_date + 1).to_i
    return 0, TrialDays if issue.isTrial?
    if status == 'LICENSED'
      if issue.start_date < invoice_since
        nrDays = (day2invoice - invoice_since).to_i
      else
        nrDays = (day2invoice - issue.start_date).to_i
      end
      if nrDays == daysThisYear
        return 1, daysThisYear
      else
        return nrDays.to_f/daysThisYear, nrDays
      end
    end
    if (invoice_since < issue.start_date)
      nrDays = (day2invoice - invoice_since).to_i
    else
      nrDays = (day2invoice - issue.start_date).to_i
    end
    if status == 'CANCELLED' or status == 'EXPIRED'
      unless issue.due_date
        return 0, 0
      end
      used_till = Date.parse(issue.updated_on.to_s)
      if used_till < invoice_since # already invoiced
        return 0, 0
      elsif (used_till - issue.start_date).to_i  < TrialDays # was less then 30 days in trial
        return 0, 0
      else
        nrDays = (day2invoice - used_till).to_i
      end
      return nrDays.to_f/daysThisYear, nrDays
    end
    puts "What TODO with status #{status} day2invoice #{day2invoice} and issue.start_date #{issue.start_date}"
    # Passiert, wenn kein custom_field status vorhanden ist
    # If you are running a test, add it via test/fixtures/custom_values
    100000 # Damit dieser Fall auch wirklich auffällt und kein Kunde dies bezahlt
  end

  def self.invoicedFeature(invoice)
    invoice.lines.collect{ |x| x.description.split('. ')[0] unless x.description.match(/gerundet/i) }.compact
    # or invoice.lines.collect{ |x| x.description.split('. ')[0] if x.description.match(/feature/) }.compact
  end

  def self.getProduct(issue)
    subject = issue.subject.sub('feature.group', 'feature').sub('feature.feature', 'feature')
    Product.where(code: subject).first
  end

  def self.findProjects2invoice(day2invoice = Date.today.end_of_year, invoice_since = nil)
    idx = 0
    invoice_since ||= Date.today.beginning_of_year
    project_ids2invoice = {}
    Project.all.each{
      | project|
        status = project.kundenstatus
        next if project.keineVerrechnung
        next unless status and ['Neukunde', 'Kunde'].index(status)
        last_invoiced = getDateOfLastInvoice(project.id, day2invoice)
        puts "Invoicing #{idx} project #{project.id}. last  #{last_invoiced} invoice_since #{invoice_since} >= #{day2invoice}? #{invoice_since ? 'No invoice found' : 'invoice_since ' + invoice_since.to_s}" if $VERBOSE
        issues = findAllOpenServicesForProjectID(project.id, day2invoice, invoice_since)
        next if issues.size == 0
        project_ids2invoice[project.id] = issues
        idx += 1
        break if OnlyFirst
    }
    project_ids2invoice
  end

  def self.getMultiplier(project)
    nrDoctors = project.nrDoctors
    multiplier = nrDoctors <= 6 ? DiscountMap[nrDoctors] : DiscountMap[6] + (nrDoctors-6)*MaxDiscount
  end

  def self.invoice_for_project(identifier, stich_tag = Date.today.end_of_year.to_date, invoice_since = Date.today.beginning_of_year, issues = nil)
    round_to = BigDecimal.new('0.05')
    puts "invoice_for_project #{identifier.inspect}"
    # Starting with redmine 3.2.7, the query returned Project::ActiveRecord_Relation and no longer a project
    project = (identifier.to_i == 0 ? Project.where(identifier: identifier).first : Project.where(id: identifier))
    project = project.first if project && project.is_a?(Project::ActiveRecord_Relation)
    raise "Projekt '#{identifier}' konnte weder als Zahl noch als Name gefunden werden" unless project
    admin = User.where(:admin => true).first
    nrDoctors = project.nrDoctors
    multiplier = getMultiplier(project)
    puts "project identifier #{identifier} with #{nrDoctors} doctors multiplier #{multiplier} keineVerrechnung #{project.keineVerrechnung} is: #{project}" if $VERBOSE
    if project.keineVerrechnung
      RedmineMedelexis.log_to_system "project '#{identifier}' #{project.name} soll nicht verrechnet werden"
      return nil
    end
    issues ||= findAllOpenServicesForProjectID(project.id, stich_tag, invoice_since)
    return if issues.size == 0
    stich_tag_string = stich_tag.strftime(DatumsFormat)
    contact = RedmineMedelexis.getHauptkontakt(project.id)
    raise "Konnte keinen Hauptkontakt für Projekt '#{identifier}' finden"  unless contact
    puts "Invoicing for #{identifier} contact #{contact} til #{stich_tag_string}" if $VERBOSE
    rechnungs_nummer = "Rechnung #{Time.now.strftime(DatumsFormat)}-#{Invoice.last ? Invoice.last.id+1 : 1}"
    invoice = Invoice.new
    last_invoiced = getDateOfLastInvoice(project.id, stich_tag)
    invoice.number = rechnungs_nummer
    invoice.invoice_date = Time.now
    invoice_since ||= getDateOfLastInvoice(project.id, stich_tag)
    invoice_since ||= Date.today.beginning_of_year.to_date
    description = "Rechnung mit Stichtag vom #{stich_tag_string} für #{nrDoctors == 1 ? 'einen Arzt' : nrDoctors.to_s + ' Ärzte'}."
    description += "\nMultiplikator für abonnierte Features ist #{multiplier}." if multiplier != 1
    description += "\n" + sprintf(Duration, invoice_since.to_s, stich_tag.to_s)
    invoice.subject = AboSubject
    invoice.project = project
    invoice.contact_id = contact.id
    invoice.due_date = (Date.today.next_month + 1)
    invoice.assigned_to = admin
    invoice.language = "DE"
    invoice.status_id  = Invoice::DRAFT_INVOICE
    invoice.currency ||= ContactsSetting.default_currency
    invoice.id = (Invoice.last.try(:id).to_i + 1).to_s
    issues.each{
      |issue|
        status = issue.custom_field_values.first.value
        product = getProduct(issue)
        next unless product
        line_description = product.name # + ". Wiki: http://wiki.elexis.info/#{subject}.feature.group"
        grund_price = product.price.to_f
        factor, days = getDaysOfYearFactor(issue, invoice_since, stich_tag)
        next if days < 0
        price = grund_price
        next if status.eql?('CANCELLED') && days <= Issue::TrialDays
        if factor == 0 || days <= Issue::TrialDays
          next if status.eql?('CANCELLED')
          next unless issue.isTrial?
          line_description += "\n#{product.name} gratis da noch im ersten Monat"
          invoice.lines << InvoiceLine.new(:description => line_description, :quantity => multiplier, :price => 0,
                                           :units => "Feature",
                                           :tax => ContactsSetting.default_tax
                                          )
          next
        elsif factor != 1
          factor = factor.round(2)
          line_description += "#{START_COMMON_LINE_INFO} von #{grund_price} wird für #{days} Tage verrechnet (Faktor #{factor})."
          price = grund_price * factor
        end
        price = price * 100 / (100 + ContactsSetting.default_tax)
        puts "found product #{product} #{product.code} #{product.price.to_f} for issue #{issue} price is #{price}" if $VERBOSE
        invoice.lines << InvoiceLine.new(:description => line_description, :quantity => multiplier, :price => price,
                                         :units => "Feature",
                                         :tax => ContactsSetting.default_tax
                                        )
    }
    # TODO: Force this order in the database
    # invoice.lines.sort_by{ |a| a.price.to_i }
    puts "Added #{invoice.lines.size} lines (of #{issues.size} service tickets). Stich_tag #{stich_tag.strftime(DatumsFormat)} due #{invoice.due_date.strftime(DatumsFormat)} description is now #{description}" if $VERBOSE
    invoice.description  = description
    invoice.custom_field_values.first.value = stich_tag_string
    invoice.save_custom_field_values
    amount = BigDecimal.new(invoice.calculate_amount.to_d)
    if amount < 5
      RedmineMedelexis.log_to_system "Invoicing for #{identifier} #{project.name} skipped as amount #{amount.round(2)} is < 5 Fr."
      invoice.delete
      RedmineMedelexis.log_to_system "Würde mit  (#{amount}) weniger als 5 Franken für '#{identifier}'  #{project.name} verrechnen"
      return nil
    end
    rounding_difference  = (amount % round_to)
    unless (rounding_difference*100) == 0
      invoice.lines << InvoiceLine.new(:description => "Gerundet zugunsten Kunde", :quantity => 1, :price => -rounding_difference)
    end
    RedmineMedelexis.log_to_system "Invoicing for #{identifier} #{project.name} amount #{amount.round(2)}. Has #{invoice.lines.size} lines "
    invoice.save
    invoice
  end

  def self.startInvoicing(stich_tag = Date.today.end_of_year.to_date, invoice_since = nil)
    projects = []
    RedmineMedelexis.log_to_system("startInvoicing: stichtag #{stich_tag.strftime(DatumsFormat)}")
    ActiveRecord::Base.transaction do
      startTime = Time.now
      oldSize = Invoice.all.size
      projects = findProjects2invoice(stich_tag, invoice_since)
      RedmineMedelexis.log_to_system "Found #{projects.size} projects. #{projects}"
      projects.each{ |id, issues| invoice_for_project(id, stich_tag, invoice_since, issues) }
      duration = (Time.now-startTime).to_i
      RedmineMedelexis.log_to_system("startInvoicing created #{Invoice.all.size - oldSize} invoices for #{projects.size} of #{Project.all.size} projects. Ids were #{projects}")
    end
    projects
  end

  def self.get_line_items(name_to_search)
    InvoiceLine.where("description like ?", "%#{name_to_search}%#{START_COMMON_LINE_INFO}%")
  end

  def self.change_line_items(from, to)
    changed_lines = []
    ActiveRecord::Base.transaction do
      get_line_items(from).sort{|x,y| x.invoice_id <=> y.invoice_id}.reverse.each do |invoice_line|
        next if Invoice.where(id: invoice_line.invoice_id).size == 0
        invoice_line.description = invoice_line.description.sub(from, to)
        invoice_line.save!
        changed_lines << invoice_line.id
      end
    end
    changed_lines
  end

  def self.get_lines(name_to_search)
    get_line_items(name_to_search).collect{|x| /(.+)#{START_COMMON_LINE_INFO}/.match(x.description)[1]}
  end
end
