#members
input = $('#input')
body = $('body')
debugDiv = $('#debug')
editor = ace.edit "input"
output = ace.edit "output"
timer = null
dialogIsOpen = false
dialog = $("<table id='dialog'></table>")
path = null

#functions
trim = (str)->str.replace(/(^\s+|\s+$)/,'')


compile = ->
	try
		compiled = CoffeeScript.compile(editor.getSession().getValue(), bare:on)
		output.getSession().setValue(compiled)
		debugDiv.html("")
	catch error
		msg = error.message
		# output.getSession().setValue(msg)
		debugDiv.html(msg)
		# line = msg.match(/line ([0-9]+)/)
		# if line isnt null and line.length > 0
			


sendReq = (data,method,callback)->
	$.ajax({
		type:method,
		url:"http://localhost:8000/"
		data:data
		timeout:3000
		success:(data, text)->
			# output.getSession().setValue data.toString()
			if data isnt null then debug "#{data.toString()}:#{text}"
			if callback? then callback data
		error:(data, err)->
			debug "REQUEST ERROR:#{data.status},#{data.statusText}"

	})

serverLog = (msg) ->
	sendReq {action:'log',message:msg}, "POST"

debug = (msg) ->
	if typeof(sg) is "object" 
		for key,val of msg
			debug "\t#{key}=#{val}"
	else 
		debugDiv.html "#{debugDiv.html()}\n#{msg}"
	# serverLog msg
	debugDiv.scrollTop debugDiv[0].scrollHeight

compileKeyBind = (e) ->
	if not e.metaKey
		if timer? then clearTimeout timer
		timer = setTimeout ( ->compile() ), 500 


jQuery.fn.center = ->
    @css("position","absolute")
    @css("top", ( $(window).height() - this.height() ) / 2+$(window).scrollTop() + "px")
    @css("left", ( $(window).width() - this.width() ) / 2+$(window).scrollLeft() + "px")
    return this;

closeDialog = ->
	if dialogIsOpen
		dialog.empty()
		dialog.remove()
		dialogIsOpen = false

showFileDialog = (p, callback) ->
	path = p
	path = path.replace "//", "/"
	dialogIsOpen = true
	debug "show save window:#{path}"
	sendReq {action:'fileList',path:path}, 'POST', (data) ->
		# debug "save window file list:#{data}"
		table = $("<table cellspacing='2' cellpadding='2' id='filebrowser'></table>")
		table.append("<colgroup><col span='1'/><col span='1' style='width:100px;'/></colgroup>")
		table.append("<thead><tr><th>file/dir name</th><th>type</th></tr></thead>")

		do ->
			if path is "/" then return
			up = path
			if up isnt "/" and up.match "/$"
				up = up.substring 0, up.length-1
			
			if up.lastIndexOf("/")>=0
				up = up.substring 0, up.lastIndexOf("/")
			
			if up is "" then up = "/"
		
			debug "up:#{up}"
			
			#note that if up = / then up will continue to = /

			cb = (file) -> 
				closeDialog()
				showFileDialog(up, callback)
			
			table.append(
				$("<tr></tr>")
					.append(
						$("<td>..</td>").click(->cb(up))
					).append(
						$("<td>directory</td>").click(->cb(up))
					)
			)

		for file,type of data
			do (file, type) ->
				#create callback function for clicking that row of the table
				if type is 'directory'
					cb = (file) -> 
						closeDialog()
						showFileDialog("#{path}/#{file}", callback)
				else if type is 'file'
					cb = (file) ->
						closeDialog()
						callback("#{path}/#{file}")
					
				table.append(
					$("<tr></tr>")
						.append(
							$("<td>#{file}</td>").click(->cb(file))
						).append(
							$("<td>#{type}</td>").click(->cb(file))
						)
				)
		
		enterBind = (e) ->
			code = if e.keyCode then e.keyCode else e.which
			if code is 13
				closeDialog()

		dialog.append(
			$("<tr></tr>").append("<td>New File Name:</td>").append(
				$("<td></td>").append(
					$("<input type='text' name='newFN' style='width:95%'/>").bind("keydown",enterBind)
				)
			)
		)


		dialog.append(
		    $("<tr></tr>").append(
		        $("<td colspan='3'></td>").append(
		            $("<div style='max-height:400px;overflow-y:scroll;'></div>").append(table)
		        )
		    )
		)
		body.append dialog
		dialog.center()

save = (file) ->
	sendReq {action:'save', content:editor.getSession().getValue(), fn:file}, 'POST', (data,err) ->
		debug 'save returned'
		if err then debug err
		debug data
		
open = (file) ->
	sendReq {action:'open', content:editor.getSession().getValue(), fn:file}, 'POST', (data,err) ->
		debug 'open returned'
		if err then debug err
		debug data
		for key, val of data
			debug "\t#{key}=#{val}"
		editor.getSession().setValue(data.content)
		compile()


specialKeyBind = (e) ->
	code = if e.keyCode then e.keyCode else e.which
	if code is 27 and dialogIsOpen
		closeDialog()
	if e.metaKey
		switch code
			when 79 then showFileDialog(path, open) #O
			when 83 then showFileDialog(path, save) #s
			else return
			
		e.preventDefault()
		e.stopPropagation()
		# debug code
		# return false

#main 
input.bind 'keypress keyup', compileKeyBind
body.bind 'keypress keydown', specialKeyBind

sendReq {action:"getConfig"}, 'POST', (data)->
	path = data.config.home
	# if data.config.lastFile?
	# 	open data.config.lastFile
	# 	path = data.config.lastFile.substring(0,data.config.lastFile.lastIndexOf('/'))




# input.bind 'keyup', (e)->
	# e.preventDefault()
	# e.stopPropagation()
	# output.html ""

#editor.setTheme "ace/theme/twilight"

CoffeeMode = require("ace/mode/coffee").Mode
editor.getSession().setMode(new CoffeeMode())

JavaScriptMode = require("ace/mode/javascript").Mode
output.getSession().setMode(new JavaScriptMode())
output.setReadOnly true

editor.focus()

if editor.getSession().getValue()?
	compile()

