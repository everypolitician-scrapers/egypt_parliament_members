#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'open-uri/cached'
require 'pry'
require 'mechanize'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def scrape_list(url, count)
  agent = Mechanize.new
  fetched = agent.get(url)

  form = fetched.form('aspnetForm')
  form.field_with(:id => 'ctl00_MainContent_DropDownList1').value = 0
  page = agent.submit(form, form.buttons[1])
  scrape_next_page(agent, page, count, url)
end

def scrape_next_page(agent, page, count, url)
  scrape_page(page, url, agent)
  count = count + 1
  count_link = page.xpath("//a[contains(.,'" + count.to_s + "')]")
  unless count_link[0].nil?
    form = page.form('aspnetForm')
    # this fakes the on page JS
    form.add_field!('__EVENTTARGET', 'ctl00$MainContent$GridView1')
    form.add_field!('__EVENTARGUMENT', 'Page$' + count.to_s)
    page = agent.submit(form)

    scrape_next_page(agent, page, count, url)
  end
end

def scrape_page(page, url, agent)
  page.css('table#ctl00_MainContent_GridView1 tr').each do |row|
    scrape_person(row, url, page, agent)
  end

end

def date_of_birth(str)
  matched = str.match(/(\d+)\/(\d+)\/(\d+)/) or return
  year, month, day = matched.captures
  "%d-%02d-%02d" % [ year, month, day ]
end

def scrape_person(row, url, page, agent)
    cells = row.css('td')
    if cells.size != 7
        return
    end

    target, arg = cells[0].css('a/@href').to_s.match("'([^']*)',\s*'([^']*)'").captures

    form = page.form('aspnetForm')
    # this fakes the on page JS
    form.add_field!('__EVENTTARGET', target)
    form.add_field!('__EVENTARGUMENT', arg)
    extra_details = agent.submit(form)

    data = {
        id: cells[1].text,
        name: cells[3].text.tidy,
        photo: cells[5].css('img/@src').text,
        source: url,
        date_of_birth: date_of_birth(extra_details.css('span#ctl00_MainContent_Label13').text),
        party: extra_details.css('span#ctl00_MainContent_Label26').text.tidy,
        cons: extra_details.css('span#ctl00_MainContent_Label24').text.tidy,
    }
    data[:photo] = URI.join(url, data[:photo]).to_s unless data[:photo].to_s.empty?

    #puts "%s - %s\n" % [ data[:name], data[:id] ]
    ScraperWiki.save_sqlite([:id], data)
end

url = 'http://www.parliament.gov.eg/members/'
scrape_list(url, 1)
