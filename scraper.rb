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
  scrape_page(page, url)
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

def scrape_page(page, url)
  page.css('table#ctl00_MainContent_GridView1 tr').each do |row|
    scrape_person(row, url)
  end

end


def scrape_person(row, url)
    cells = row.css('td')
    if cells.size != 7
        return
    end
    name = cells[3].text.tidy

    data = {
        id: cells[1].text,
        name: name,
        photo: cells[5].css('img/@src').text,
    }
    data[:photo] = URI.join(url, data[:photo]).to_s unless data[:photo].to_s.empty?

    #puts "%s - %s\n" % [ data[:name], data[:id] ]
    ScraperWiki.save_sqlite([:id], data)
end

url = 'http://www.parliament.gov.eg/members/'
scrape_list(url, 1)
