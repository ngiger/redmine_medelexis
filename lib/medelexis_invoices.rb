#!/usr/bin/env ruby
#encoding: utf-8

File.expand_path('../redmine_medelexis', __FILE__)
require 'medelexis_helpers'

class Project
  def keineVerrechnung
    return false unless field = CustomField.find(:first, :conditions => { :name => 'Keine Verrechnung'} )
    return false unless custom = custom_value_for(field.id)
    custom.value.to_i > 0 ? true : false
  end
  def nrDoctors
    field = CustomField.find(:first, :conditions => { :name => '# Ärzte'} )
    if (field && custom_value_for(field))
      custom_value_for(field).value.to_i
    else
      ''
    end
  end
  def nrStations
    field = CustomField.find(:first, :conditions => { :name => '# Stationen'} )
    if (field && custom_value_for(field))
      custom_value_for(field).value.to_i
    else
      ''
    end
  end
  def systemProperties
    field = CustomField.find(:first, :conditions => { :name => 'systemProperties'} )
    if (field && custom_value_for(field))
      custom_value_for(field).value
    else
      ''
    end
  end
  def kundenstatus
    custom_field_values # forces evaluation. Avoids an error in test/functional
    field = CustomField.find(:first, :conditions => { :name => 'Kundenstatus'} )
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

  def self.stichtag(invoice)
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
    info = "#{issue.id} #{status}: #{invoice_since}-#{stich_tag} for issue #{issue.start_date} - #{issue.updated_on}"
    return false if status.eql?('CANCELLED') && (issue.updated_on.to_date - issue.start_date.to_date).to_i <= TrialDays
    if status.eql?('CANCELLED') || status.eql?('EXPIRED')
       if (issue.updated_on < invoice_since) || (issue.start_date > stich_tag)
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
    all_project_issues = Issue.find(:all, :conditions => { :project_id => project_id, :tracker_id => RedmineMedelexis::Tracker_Is_Service} )
    invoices = Invoice.find(:all, :conditions => {:project_id => project_id}).reject{ |invoice| stichtag(invoice) == nil || stichtag(invoice) < invoice_since }
    last_invoice = getLastInvoiceForProject(project_id)
    return all_project_issues unless last_invoice
    open_issues = []
    core_name = Product.first.name
    # binding.pry if $VERBOSE
    return all_project_issues if (last_invoice &&  (stichtag(last_invoice) < stich_tag))
    all_project_issues.each do |issue|
      if !issueDateInRange?(issue, stich_tag, invoice_since)
        puts "Skipping #{issue.id} #{issue.subject} with #{issue.start_date}" if $VERBOSE
      else
        product = getProduct(issue)
        if !product
          puts "Skip no product for #{issue.id} #{issue.subject}" if $VERBOSE
        elsif product.price.to_f.to_i == 0
          puts "Skip price #{issue.id} #{issue.subject}" if $VERBOSE
        elsif last_invoice &&
            product.name.eql?(core_name) &&
            last_invoice.lines.find_all{|line| /#{core_name}/i.match(line.description)  }.size > 0
            puts "Skip #{core_name} line #{issue.id}" if $VERBOSE
        elsif last_invoice
          lines = last_invoice.lines.find_all{|line| line.description.index(product.name) }
          if /gratis/i.match(lines.first.description)
            puts "Add gratis product #{issue.id} #{product.name}" # if $VERBOSE
          else
            puts "Skip matched product #{issue.id} #{product.name}" # if $VERBOSE
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

  def self.getLastInvoiceForProject(project_id)
    projects = Project.find(:all, :conditions => { :id => project_id } )
    unless projects.size > 0
      puts "getDateOfLastInvoice no projects found for #{project_id}" if $VERBOSE
      return nil
    end
    project = projects.first
    invoices = Invoice.find(:all, :conditions => {:project_id => project.id}).reject{ |invoice| stichtag(invoice) == nil }
    unless invoices.size > 0
      puts "getDateOfLastInvoice no invoices found for #{project_id}" if $VERBOSE
      return nil
    end
    last = invoices.max {|a,b| stichtag(a) <=> stichtag(b) }
  end

  def self.getDateOfLastInvoice(project_id)
    last = getLastInvoiceForProject(project_id)
    return nil unless last
    lastDate = stichtag(last)
    puts "getDateOfLastInvoice lastDate for #{project_id} was #{lastDate}" if $VERBOSE
    lastDate
  end

  def self.getDaysOfYearFactor(issue_id, invoice_since, day2invoice = Date.today.to_datetime.end_of_year)
    issue = Issue.find(:first, :conditions => {:id => issue_id})
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
      used_till = issue.updated_on.to_date
      if used_till < invoice_since # already invoiced
        return 0, 0
      elsif (used_till - invoice_since).to_i < TrialDays
        nrDays = (used_till - invoice_since).to_i
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
    Product.find(:first, :conditions => {:code => subject})
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
        last_invoiced = getDateOfLastInvoice(project.id)
        puts "Invoicing #{idx} project #{project.id}. last  #{last_invoiced} invoice_since #{invoice_since} >= #{day2invoice}? #{invoice_since ? 'No invoice found' : 'invoice_since ' + invoice_since.to_s}" if $VERBOSE
        issues = findAllOpenServicesForProjectID(project.id, day2invoice, invoice_since)
        next if issues.size == 0
        project_ids2invoice[project.id] = issues
        idx += 1
        break if OnlyFirst
    }
    project_ids2invoice
  end

  def self.invoice_for_project(identifier, stich_tag = Date.today.end_of_year.to_date, invoice_since = Date.today.beginning_of_year, issues = nil)
    round_to = BigDecimal.new('0.05')
    if identifier.to_i >0
      project= Project.find(identifier.to_i)
    else
      project= Project.find(:first,  :conditions => {:identifier => identifier})
    end
    raise "Projekt '#{identifier}' konnte weder als Zahl noch als Name gefunden werden" unless project
    admin = User.find(:first, :conditions => {:admin => true})
    nrDoctors = project.nrDoctors
    multiplier = nrDoctors <= 6 ? DiscountMap[nrDoctors] : DiscountMap[6] + (nrDoctors-6)*MaxDiscount
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
    last_invoiced = getDateOfLastInvoice(project.id)
    invoice.number = rechnungs_nummer
    invoice.invoice_date = Time.now
    invoice_since ||= getDateOfLastInvoice(project.id)
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
        factor, days = getDaysOfYearFactor(issue.id, invoice_since, stich_tag)
        next if days < 0
        price = grund_price
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
    invoice.lines.sort! { |a,b| b.price.to_i <=> a.price.to_i } # by price descending
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