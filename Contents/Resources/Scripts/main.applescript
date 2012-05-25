property PathInfo : module
property FinderSelection : module
property FrontAccess : module
property XFile : module
property InferiorTerminal : module
property loader : boot (module loader) for me

property _commit_msg : ""

on run
	try
		main()
	on error msg number errno
		if errno is not -128 then
			activate
			display alert msg message "Error Number : " & errno
		end if
	end try
end run


on update_decompile(a_target)
	set a_target to XFile's make_with_pathinfo(a_target)
	set scpt_file to a_target's child("Contents/Resources/Scripts/main.scpt")
	set decompiled_file to scpt_file's change_path_extension("applescript")
	if scpt_file's info()'s modification date > decompiled_file's info()'s modification date then
		do shell script "osadecompile " & scpt_file's posix_path()'s quoted form & " > " & decompiled_file's posix_path()'s quoted form
	end if
end update_decompile

on git_diff(a_target)
	update_decompile(a_target)
	set cd_command to "cd " & a_target's posix_path()'s quoted form
	--InferiorTerminal's do(cd_command & ";git diff Contents/Resources/Scripts/main.applescript")
	InferiorTerminal's do(cd_command & ";git diff")
end git_diff

on open_terminal(a_target)
	set cd_command to "cd " & a_target's posix_path()'s quoted form
	InferiorTerminal's do(cd_command)
end open_terminal

on export_target(a_target)
	set a_location to choose folder with prompt "Choose a location to export:"
	set a_destination to PathInfo's make_with(a_location)'s child(a_target's item_name() & "/")
	set cd_command to "cd " & a_target's posix_path()'s quoted form
	set git_command to "git checkout-index -a -f --prefix=" & a_destination's posix_path()'s quoted form
	set all_command to cd_command & ";" & git_command
	set a_result to do shell script "$SHELL -lc " & all_command's quoted form
	if a_result's length is not 0 then
		display alert a_result
	else
		display alert "Succeeded export"
	end if
end export_target

on update_precommit(a_target)
	set x_me to XFile's make_with(path to me)
	set pre_commit to x_me's bundle_resource("pre-commit")
	pre_commit's copy_to(a_target's child(".git/hooks/"))
end update_precommit

on git_init(a_target)
	set cd_command to "cd " & (a_target's posix_path()'s quoted form)
	set all_command to cd_command & ";git init"
	do shell script "$SHELL -lc " & (all_command's quoted form)
	update_precommit(a_target)
	set all_command to cd_command & ";git add Contents"
	do shell script "$SHELL -lc " & (all_command's quoted form)
end git_init

on modified_files(a_target)
	set cd_command to "cd " & a_target's posix_path()'s quoted form
	set git_command to "git status -s| grep '^ *M '|sed 's/^ *M *//g'"
	set all_command to cd_command & ";" & git_command
	set a_result to do shell script "$SHELL -lc " & all_command's quoted form
	return a_result
end modified_files

on process_item(a_target)
	if not a_target's child("Contents/Resources/Scripts")'s item_exists() then
		error "Not a script bundle :" & return & a_target's posix_path() number 2080
	end if
	
	if not a_target's child(".git")'s item_exists() then
		activate
		display dialog "Perform 'git init' for " & a_target's item_name()'s quoted form & " ?"
		git_init(a_target)
	end if
	activate
	set a_result to ¬
		choose from list {"commit -a", "push", "status -s", "diff", "export", "-------", "Terminal", "GitX", "Update pre-commit"} ¬
			with title "git-scptd" with prompt "Actions for " & a_target's item_name()'s quoted form & ¬
			" :" without multiple selections allowed and empty selection allowed
	if class of a_result is list then
		set an_action to item 1 of a_result
		set git_command to "git " & an_action
		if an_action is "diff" then
			return git_diff(a_target)
		else if an_action is "export" then
			return export_target(a_target)
		else if an_action is "Terminal" then
			return open_terminal(a_target)
		else if an_action is "GitX" then
			tell application "GitX"
				open a_target's as_furl()
			end tell
			activate process identifier "nl.frim.GitX"
			return
		else if an_action is "Update pre-commit" then
			return update_precommit(a_target)
		else if an_action starts with "-----" then
			return
		else if an_action starts with "commit" then
			set file_list to modified_files(a_target)
			if not file_list's length > 0 then
				return
			end if
			set msg to "Modified files :" & return & file_list & return & return & "Commit message :"
			set a_result to display dialog msg default answer my _commit_msg
			set my _commit_msg to a_result's text returned
			set git_command to git_command & " -m " & my _commit_msg's quoted form
		end if
		set cd_command to "cd " & a_target's posix_path()'s quoted form
		set all_command to cd_command & ";" & git_command
		set a_result to do shell script "$SHELL -lc " & all_command's quoted form
		activate
		if a_result's length is not 0 then
			display alert a_result
		else
			display alert "Succeeded " & an_action's quoted form
		end if
	end if
end process_item

on main()
	set a_front to make FrontAccess
	--if (("com.apple.finder" is a_front's bundle_identifier()) or (a_front's is_current_application())) then
	if ("com.apple.finder" is a_front's bundle_identifier()) then
		set a_picker to FinderSelection's make_for_package()
		tell a_picker
			set_extensions({".scptd", ".app"})
			set_use_chooser(false)
		end tell
		set a_selection to a_picker's get_selection()
		if a_selection is not missing value then
			set a_target to PathInfo's make_with(item 1 of a_selection)
			process_item(a_target)
		end if
	else
		set a_file to a_front's document_alias()
		open {a_file}
	end if
end main

on open a_list
	set a_target to PathInfo's make_with(item 1 of a_list)
	if a_target's path_extension() is in {"scptd", "app"} then
		process_item(a_target)
	end if
end open
