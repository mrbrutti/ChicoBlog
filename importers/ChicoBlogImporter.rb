require 'rubygems'
require 'rexml/document'
require 'digest/md5'
require 'json'
require 'date'
require 'getoptlong'
require 'nokogiri'
require 'uri'


@posts = []
@authors = []

# obtained from https://github.com/singpolyma/HTML2Markdown
# encoding: utf-8
# Thanks for the awesome library :-)
class HTML2Markdown

	def initialize(str, baseurl=nil)
		@links = []
		@baseuri = (baseurl ? URI::parse(baseurl) : nil)
		@section_level = 0
		@encoding = str.encoding
		@markdown = output_for(Nokogiri::HTML(str, baseurl).root).gsub(/\n\n+/, "\n\n")
	end

	def to_s
		i = 0
		@markdown.to_s + "\n\n" + @links.map {|link|
			i += 1
			"[#{i}]: #{link[:href]}" + (link[:title] ? " (#{link[:title]})" : '')
		}.join("\n")
	end

	def output_for_children(node)
		node.children.map {|el|
			output_for(el)
		}.join
	end

	def add_link(link)
		if @baseuri
			begin
				link[:href] = URI::parse(link[:href])
			rescue Exception
				link[:href] = URI::parse('')
			end
			link[:href].scheme = @baseuri.scheme unless link[:href].scheme
			unless link[:href].opaque
				link[:href].host = @baseuri.host unless link[:href].host
				link[:href].path = @baseuri.path.to_s + '/' + link[:href].path.to_s if link[:href].path.to_s[0] != '/'
			end
			link[:href] = link[:href].to_s
		end
		@links.each_with_index {|l, i|
			if l[:href] == link[:href]
				return i+1
			end
		}
		@links << link
		@links.length
	end

	def wrap(str)
		return str if str =~ /\n/
		out = ''
		line = []
		str.split(/[ \t]+/).each {|word|
			line << word
			if line.join(' ').length >= 74
				out << line.join(' ') << " \n"
				line = []
			end
		}
		out << line.join(' ') + (str[-1..-1] =~ /[ \t\n]/ ? str[-1..-1] : '')
	end

	def output_for(node)
		case node.name
			when 'head', 'style', 'script'
				''
			when 'br'
				"  \n"
			when 'p', 'div'
				"\n\n#{wrap(output_for_children(node))}\n\n"
			when 'section', 'article'
				@section_level += 1
				o = "\n\n----\n\n#{output_for_children(node)}\n\n"
				@section_level -= 1
				o
			when /h(\d+)/
				"\n\n" + ('#'*($1.to_i+@section_level) + ' ' + output_for_children(node)) + "\n\n"
			when 'blockquote'
				@section_level += 1
				o = ("\n\n> #{wrap(output_for_children(node)).gsub(/\n/, "\n> ")}\n\n").gsub(/> \n(> \n)+/, "> \n")
				@section_level -= 1
				o
			when 'ul'
				"\n\n" + node.children.map {|el|
					next if el.name == 'text'
					"* #{output_for_children(el).gsub(/^(\t)|(    )/, "\t\t").gsub(/^>/, "\t>")}\n"
				}.join + "\n\n"
			when 'ol'
				i = 0
				"\n\n" + node.children.map {|el|
					next if el.name == 'text'
					i += 1
					"#{i}. #{output_for_children(el).gsub(/^(\t)|(    )/, "\t\t").gsub(/^>/, "\t>")}\n"
				}.join + "\n\n"
			when 'pre', 'code'
				block = "\t" + wrap(output_for_children(node)).gsub(/\n/, "\n\t")
				if block.count("\n") < 1
					"`#{output_for_children(node)}`"
				else
					block
				end
			when 'hr'
				"\n\n----\n\n"
			when 'a', 'link'
				link = {:href => node['href'], :title => node['title']}
				"[#{output_for_children(node).gsub("\n",' ')}][#{add_link(link)}]"
			when 'img'
				link = {:href => node['src'], :title => node['title']}
				"![#{node['alt']}][#{add_link(link)}]"
			when 'video', 'audio', 'embed'
				link = {:href => node['src'], :title => node['title']}
				"[#{output_for_children(node).gsub("\n",' ')}][#{add_link(link)}]"
			when 'object'
				link = {:href => node['data'], :title => node['title']}
				"[#{output_for_children(node).gsub("\n",' ')}][#{add_link(link)}]"
			when 'i', 'em', 'u'
				"_#{output_for_children(node)}_"
			when 'b', 'strong'
				"**#{output_for_children(node)}**"
			# Tables are not part of Markdown, so we output WikiCreole
			when 'tr'
				node.children.select {|c|
					c.name == 'th' || c.name == 'td'
				}.map {|c|
					output_for(c)
				}.join.gsub(/\|\|/, '|') + "\n"
			when 'th', 'td'
				"|#{'=' if node.name == 'th'}#{output_for_children(node)}|"
			when 'text'
				# Sometimes Nokogiri lies. Force the encoding back to what we know it is
				if (c = node.content.force_encoding(@encoding)) =~ /\S/
					c.gsub!(/\n\n+/, '<$PreserveDouble$>')
					c.gsub!(/\s+/, ' ')
					c.gsub(/<\$PreserveDouble\$>/, "\n\n")
				else
					c
				end
			else
				wrap(output_for_children(node))
		end
	end
end

def gravatar(email)
	return "http://www.gravatar.com/avatar/#{Digest::MD5.hexdigest(email.downcase)}"
end

def author(displayname)
	return @authors.select {|x| x["displayname"] == displayname}
end


opts = GetoptLong.new(
  [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
  [ '--wordpress','-w', GetoptLong::REQUIRED_ARGUMENTT ],
  [ '--output','-o', GetoptLong::REQUIRED_ARGUMENT ]
)

opts.each do |opt, arg|
  case opt
    when '--help' then
      # BEGIN OF HELP
      puts "IOA to SQLite3:\n\n"
      puts "\t--help,    -h\tThis help menu."
      puts "\t--wordpress,   -v\tThe .xml file containing the posts."
      puts "\t--output,  -d\tName of output .json file."
      puts ""
      puts "Copyright 2013 - EvilRovot\n"
      #END OF HELP
      exit(0)
    when '--wordpress' then
      @wordpress_xml_file = arg
    when '--output' then
      @output_json_file = arg
    else
      puts "[!] - option not recognized.\n"
      exit(1)
    end
end


if @wordpress_xml_file 
	xml_file = File.new(@wordpress_xml_file)
	document = REXML::Document.new(xml_file).root.elements['channel']

	# build the author's list
	document.elements.each('wp:author') do |author|
		fullname = "#{author.elements["wp:author_first_name"].text} #{author.elements["wp:author_last_name"].text}".strip
		fullname = author.elements["wp:author_display_name"].text if fullname == ""

		@authors << {
			"login" => author.elements["wp:author_login"].text,
			"email" => author.elements["wp:author_email"].text,
			"gravatar" => gravatar(author.elements["wp:author_email"].text),
			"fullname" => fullname,
			"displayname" => author.elements["wp:author_display_name"].text
		}
	end
	# generate posts array.
	document.elements.each("item") do |item|
		begin
			puts "[*] - Importing (#{item.elements['title'].text})"
			tags = []
			item.elements.each('category') {|y| tags << { "tag" => y.text } }
			@posts << {
				"title" => item.elements['title'].text,
				"content" => HTML2Markdown.new(item.elements["content:encoded"].text).to_s,
				#"content" => item.elements["content:encoded"].text.gsub("\n\n","<br>").gsub("</code>","</code></pre>").gsub(/<code.*>/,"<pre><code>"),
				"timestamp" => DateTime.parse(item.elements['wp:post_date'].text).strftime("%F %T"),
				"tags" => tags,
				"author" => author(item.elements['dc:creator'].text).first["fullname"],
				"authorimage" => author(item.elements['dc:creator'].text).first["gravatar"]
			}
		rescue
			puts "[!] - Failed (#{item.elements['title'].text})"
		end
	end
	# write to disk in json format
	File.open(@output_json_file || "output.json", 'w') { |file| file.write(JSON.pretty_generate @posts) }
else
	puts "[!] - No WordPress XML file provided."
end
