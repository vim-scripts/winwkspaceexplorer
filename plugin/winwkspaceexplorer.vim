"=============================================================================
"    Copyright: Copyright (C) 2007 Narinder Claire
"               Permission is hereby granted to use and distribute this code,
"               with or without modifications, provided that this copyright
"               notice is copied with it. Like anything else that's free,
"               winwkspaceexplorer.vim is provided *as is* and comes with no
"               warranty of any kind, either expressed or implied. In no
"               event will the copyright holder be liable for any damages
"               resulting from the use of this software.
" Name Of File: winwkspaceexplorer.vim
"  Description: Workspace Explorer Vim Plugin (Plugin for winamanager)
"               winwkspaceexplorer.vim is a plugin which helps to organise a
"               group of projects in a workspace rather like IDEs 
"   Maintainer: Narinder Claire   : narinder_claire AT yahoo.co.uk
" Last Changed: Thursday 24th April 2008 
"      Version: 0.33.2
"        Usage: This file should reside in the plugins directory and be 
"               automatically sourced. It has a dependency on the plugin 
"               winmanager which should be installed
"
"
"               For more help see supplied documentation.
"      History: See supplied documentation.
"=============================================================================


" Has this already been loaded?
if exists("g:loaded_winwkspaceexplorer")
  finish
endif

let g:loaded_winwkspaceexplorer=1


" Line continuation used here
let s:cpo_save = &cpo " Do I really need this here ?
set cpo&vim
" OK let the user overide the default extensions for project files and 
" workspace files. She can define them in .vimrc
if !exists("g:wksExtension")
		 let g:wksExtension = ".vimwks" 
end

if !exists("g:projExtension")
		 let g:projExtension = ".vimprj"
end





" Lets set up the default Workspace explorer colours. if the dictionary
" doesn't alread exist ... You could define this in .vimrc 
if !exists("g:WorkspaceExplorerColours")
                let g:WorkspaceExplorerColours = {}
		let g:WorkspaceExplorerColours["Worksapce"] = "Directory"
		let g:WorkspaceExplorerColours["Project"] = "String"
		let g:WorkspaceExplorerColours["Filter"] = "Type"
		let g:WorkspaceExplorerColours["File"] = "Keyword"
endif


"variable used to store the name of the WorkSpace file
let s:pathname=''
"A veriabelt o store the workspace Dictionary
let s:wksDict={}
let s:dirtyFlag = 1
"This will be a flag to be used for folding. We're not going use vim folding
"it doesn't seem to offer what I need ( but I maybe wrong)
let s:globalFold=0
" -- stuff used by winmanager
"
"

" These function are neccessary to hook into 
" winmanager. The documenation for hooking can be founf in the doc that
" comes with that plugin
let g:WKSpaceExplorer_title = "[Workspace]"
function! WKSpaceExplorer_Start()
		 let b:displayMode = "winmanager"
		 setlocal nonumber

                 if s:pathname!=''
                                 if s:dirtyFlag==0
                                    call s:upDateOnModified()
                                 endif
		 		 call s:EditWKS(s:pathname)
		 else
                                 let s:dirtyFlag = 1 
		 		 call s:EditWKS(getcwd()."/".fnamemodify(getcwd(),":t:r").g:wksExtension)
		 endif
		 if exists('s:lastCursorRow')
		 		 exe s:lastCursorRow
		 		 exe 'normal! '.s:lastCursorColumn.'|'
		 endif
endfunction


let s:refreshFlag = 0
function! WKSpaceExplorer_IsValid()
                 call s:upDateOnModified()
		 return 1-s:dirtyFlag
endfunction


function! WKSpaceExplorer_Refresh()
		 call s:EditWKS(s:pathname)

endfunction



function! WKSpaceExplorer_WrapUp()
		 let s:lastCursorRow = line('.')
		 let s:lastCursorColumn = virtcol('.')
endfunction
" --- end winmanager specific stuff 

"---
"
"This is a silly way to do this but hey .....
"This sstring is used to give the spaces for displaying files names in the
"WorkspaceExplorer
let s:spacesString="                                   "


"---
"By default we do not want to change the operation of the default winmanager 
"We only want to enter Workspacve Explorer when asked to do with this command
" Create commands
if !exists(':WKSpace')
   "May take one parameter , the name 'file.vimwks'. If nothing is given
   "Open a woekspace files named after the curent directory
   command -nargs=? -complete=file WKSpace :call s:StartExplorer(<f-args>)|WManager

endif
"---
"
"
"
"Wntry point
function! s:StartExplorer(...)
  " OK we have been specificaly asked to modify the behaviour of 
  " WinMAnager to behave like a WorkSpace Explorer
  let s:winManagerWindowLayout=g:winManagerWindowLayout
  if exists("g:winwksexplorerWindowLayout")
      let g:winManagerWindowLayout = g:winwksexplorerWindowLayout
  else
      let g:winManagerWindowLayout = 'WKSpaceExplorer,TagsExplorer,FileExplorer|BufExplorer'
  endif
  " If no file name is passed in use the name of the current directory
  if a:0==0
    let s:pathname = getcwd()."/".fnamemodify(getcwd(),":t:r").g:wksExtension 
  else
    let s:pathname=fnamemodify(a:1,":p")
  endif

  let s:dirtyFlag = 1

endfunction

" Probably can get rid of this
function! s:joinPaths(parent,child)
  if a:child[0]=='/'
    return a:child
  endif
  return a:parent.'/'.a:child

endfunction

" Ok this function reads in the workspace file and all the constitent 
" project files and builds an internal dictionary ( tree ) with a node for each
" file referenced in the project file
function! s:toDict(fullpath,name)
    let l:directory = fnamemodify(a:fullpath,":p:h")
    
    let l:theDict ={}
    let l:projectLines = readfile(a:fullpath)
    let s:wksModTime  = getftime(a:fullpath)

    "Lets loop through all the projects listed in the workspace file
    for proj in l:projectLines 
        " Get a 'List' of all the projects. They should be project filenames
        " relative to the workspace file 
        let l:projSplit = split(proj)

        " Q:Why are we checking that each line in the workspace file has
        " only has one item, the relative  path to a project file ?
        " A:We can see ourselves having more than just a relative pathname and
        " have other things here of interest .... for example a string
        " identifyiing the source repoitry of the project .. 
        if len(l:projSplit)==1

            " Lets get the project NAME without any of the path info or the
            " extension
            let l:projName = fnamemodify(l:projSplit[0],":t:r")

            " Initialise the Subictionary to hold the tree for this project
            let theDict[projName]={}

            " We better store its filename ( relative to the workspace file)
            let theDict[projName]['filename']=l:projSplit[0]

            "A flag to tell us whether this project is folded bu first check
            "if this project is already in the s:wksDict , if so then just use
            "that value
            if has_key(s:wksDict,projName)
              let theDict[projName]['fold']=s:wksDict[projName]['fold']
              let l:hasProj = 1
            else
              let theDict[projName]['fold']=1
              let l:hasProj = 0
            endif

            " OK lets read in this project file
            let l:projectRaw = readfile(s:joinPaths(l:directory,l:projSplit[0]))

            let l:theDict[projName]['modtime']= getftime(s:joinPaths(l:directory,l:projSplit[0]))

            " l:projectRaw does indeed hold a list of all the files AND filter
            " names in the project BUT with gunk like spaces and tabs possibly
            let l:projectClean = []
            for f in l:projectRaw
                let l:fline = split(f) " split will remove any unwanted spaces
                if len(l:fline)==1     " Q: Why 1 ? A: What if we wantr to store extra info about the file 
                    let l:projectClean = l:projectClean + l:fline
                endif
            endfor 
            " OK so now we have a list f all filenames

            "Ok lets set up a subictionary for all the filters ( virtual
            "folders, sections or whatever) in this project
            let l:theDict[projName]['filters']={}
            
            "For files that don't actualy fall into any filter, it will be
            "convenient to to put them into a filter called ' ' ( exactly 1
            "space)
            let l:vf=' '

            "Each filter will be a subictionary itself with (key, value) = (
            "short filename, relative pathname of file)
            let l:theDict[projName]['filters'][l:vf]={}
            let l:theDict[projName]['filters'][l:vf]['files']={}

            "We will probably never have folding for this fikter but we set
            "this flag anyway
            let l:theDict[projName]['filters'][l:vf]['fold']=0
            " OK lets work our way through all the files but look out for any
            " name of he type '<xxxX>' becauyse anything between <> will be
            " considered a filter name fo all following files untill we hit the
            " next filter name
            for f in l:projectClean
                  if f =~ '^<.\+>$' " This reg exp stuff is cool, I have never used it for !

                      " If we have found a filter lets get rid of the angular
                      " brackets <><
                      let l:vf= split(f,'[<>]')[0]

                      " and put it in the filters subictionary
                      let l:theDict[projName]['filters'][l:vf]={}
                      " A flag to tell us whether this filter is folded
                      let l:theDict[projName]['filters'][l:vf]['fold']=0
                      if l:hasProj
                        if has_key(s:wksDict[projName]['filters'],l:vf)
                          let l:theDict[projName]['filters'][l:vf]['fold']=s:wksDict[projName]['filters'][l:vf]['fold']
                        endif
                      endif


                      let l:theDict[projName]['filters'][l:vf]['files']={}
                  else
                      " If it was not a filter name must be a file name, lets
                      " stor its short name along with relative path ( relative
                      " from project file)
                      let l:theDict[projName]['filters'][l:vf]['files'][fnamemodify(f,":t")]=f
                  endif

            endfor
        endif
    endfor
  return l:theDict

endfunction


function! s:upDateOnModified()
  if getftime(s:wksFullPath)!=s:wksModTime
      let s:dirtyFlag = 1
      return
  endif
  
  for pk in keys(s:wksDict)
      let l:projFileName =  (s:joinPaths(s:wksDirectory,s:wksDict[pk]['filename']))
      if getftime(l:projFileName)!=s:wksDict[pk]['modtime']
        let s:dirtyFlag = 1
        return
       endif
  endfor





endfunction



" This is the main entry for 'editing' a WorkSpace
" It is called everytime the buffer needs an update or when we first use
" WKSpace f.vimwks
function! s:EditWKS(...)
  " No one execpt us is going to touch out buffer !!
  set modifiable

  "clear it all
  1,$d_

  " If no parameters were passed .. then use the current directory name for the
  " .vimwks filei
  "
  if s:dirtyFlag ==1
  if a:0 == 0
     let name = getcwd()."/".fnamemodify(getcwd(),":t:r").g:wksExtension
  elseif a:0 >= 1
    let name =fnamemodify( a:1,":p")
  endif		 
         
    "Lets see if the extension of the given filename is correct, by default
    "this should be .vimwks. Also the variable name holds the name of the
    "wkspace file ( the full name including the path)    
    let l:actualExt = '.'.fnamemodify(name,":e")
    if !(l:actualExt==g:wksExtension)
          put='ERROR '
          put=name.' is not a Work Space file '
          let s:pathname=''
          return
		 endif

        "If no filename was given and we are using the name of the current
        "directory for the workspace file then it may not exist already, so
        "lets make sure it does
        if !(filereadable(name))
            call writefile([''],name)    
        endif



                " Lets store some values in script variables rather than just
                " locally
                let s:wksFullPath=name
                let s:wksName=fnamemodify(name,":t:r")
                let s:wksDirectory = fnamemodify(name,":p:h")

                " Lets build the workspace dictionary ( tree ) from the
                " workspace file
                let s:wksDict = s:toDict(s:wksFullPath,s:wksName)
          endif
                 " I think this is from one of the explorers that come with
                 " winmanager
		 " Turn off the swapfile, set the buffer type so that it won't get
		 " written, and so that it will get deleted when it gets hidden.
		 setlocal noswapfile
		 setlocal buftype=nowrite
		 setlocal bufhidden=delete
		 " Don't wrap around long lines
		 setlocal nowrap

		 iabc <buffer>
	" set up some Basic  elementary syntax highlighting.
	if has("syntax") && !has("syntax_items") && exists("g:syntax_on")
		syn match Worksapce '\[.\+'   
		syn match Project '\s*<.\+>$' 
		syn match Filter '\s*|.\+|$'
		syn match File '\s*[^<\[|].\+[^>\]|]$'

                for k in keys(g:WorkspaceExplorerColours)

                    exec "hi def link ".k." ".g:WorkspaceExplorerColours[k]
                endfor 
        endif


		 " Set up mappings for this buffer
		 let cpo_save = &cpo
		 set cpo&vim

                 " when <CR> is pressed on a filename , edit it in the main
                 " window
		 nnoremap <silent> <buffer> <cr> :call <SID>EditEntry(0)<cr>
		 imap <silent> <buffer> <cr> <Esc>:call <SID>EditEntry(0)<cr>

                 " When <TAB> is pressed on a filename, split the main wiondows
                 "
                 " and edit it there
                 nnoremap <silent> <buffer> <tab> :call <SID>EditEntry(1)<cr>
                 imap <silent> <buffer> <tab> <Esc>:call <SID>EditEntry(1)<cr>
		 
                 
                 "double click same a as pressing <CR>
                 nnoremap <silent> <buffer> <2-leftmouse> :call <SID>EditEntry(0)<cr>
                 imap <silent> <buffer> <2-leftmouse> <Esc>:call <SID>EditEntry(0)<cr>
		 let &cpo = cpo_save
                  
          let s:dirtyFlag = 0
                call s:DisplayDict()
		 " prevent the buffer from being modified
                 1 " Put the cursor back to the beggining ... do we REALLY need to this ?
		 setlocal nomodifiable
endfunction
                
" Function to actualy Display the WorkSpace Dictionary in the window 
function! s:DisplayDict()
                " No one execpt us is going to touch out buffer !!
                setlocal modifiable

                "clear it all
                1,$d_

		 " Show the files. We're now going to diasplay the dictionary
                 " in our buffer 
                 "
                 " The Title
                 "

                "Is global fold set ? If so .. dob't display anything other
                "than the workspace name
                if s:globalFold==1
                 put='[[Workspace: '.s:wksName.']]'
                else
                 put='[Workspace: '.s:wksName.']'

                 " Now lets go through each project. We want to indent
                 " increasingly each level in th  tree. The number of
                 " indente=ing spaces will be held in l:spaces
                 for l in sort(keys(s:wksDict))
                   let l:spaces=2

                   "Display the project name in the brackest <> proceeded with
                   "an indent
                   " but first check in case fold flag is set for this project
                   " .. if so JUST diaply the project name in << >>
                   if s:wksDict[l]['fold']==1
                    let l:temp = s:spacesString[0:l:spaces].'<<'.l.'>>'
                    put=l:temp
                   else
                   let l:temp = s:spacesString[0:l:spaces].'<'.l.'>'
                   put=l:temp

                    " Lets work through all the filters for this project
                    for ll in sort(keys(s:wksDict[l]['filters']))
                      let l:spaces=6
                      if s:wksDict[l]['filters'][ll]['fold']==1
                          let l:temp = s:spacesString[0:l:spaces].'||'.ll.'||'
                          put=l:temp
                      else
                        "This is the default filter ' ', no need to diaply
                        "anything here 
                        if ll!=' '
                          let l:temp = s:spacesString[0:l:spaces].'|'.ll.'|'
                          put=l:temp
                          let l:spaces=10
                        endif

                        "Lets display all the files under the filter
                        for lll in sort(keys(s:wksDict[l]['filters'][ll]['files']))
                          let l:temp = s:spacesString[0:l:spaces].lll
                          put=l:temp
                        endfor
                      endif " ending if endif for fold flag on filter
                    endfor
                  endif  " ending if endif for fold flag on project
                 endfor  " ending for for looping over projects

                endif "ending id for s:globalFold
                setlocal nomodifiable


endfunction


" We come here if we get a  <CR>, <TAB> or a double click on a line in our
" buffer
function! <SID>EditEntry(split)

  "If we are at the very top 

  " We may need to change directory to get at what we want, especialy as we
  " have insisting all filenames as RELATIVE paths, so lets save current dir so
  " we can come back to it later 
  let l:cwd = getcwd()

  " what is the text under the cursor , we are hoping it will be a file, lets
  " use split to get rid of the spaces
  let l:fileList=split(getline('.'))
  if len(l:fileList)==0
  " Just an empty line .. not interested 
    return  
  endif

  let l:file = l:fileList[0]

  "----------------------------- Lets check for folding first -------------"
  "
  " Am I trying to toggle folding for the wholeworkspace 
  if (l:file=~'\[.\+')
      let s:globalFold = 1 - s:globalFold
      call s:DisplayDict()
      return
  endif


  "Am I trying to toggle the folding on a project
  if (l:file=~'\s*<.\+>$')
      let l:projName = split(l:file,'[<> ]')[0]
      let s:wksDict[l:projName]['fold'] = 1-s:wksDict[l:projName]['fold']
      call s:DisplayDict()
      return

  endif
  
  "Am I trying to toggle the folding for a filter ? 
  if (l:file=~'\s*|.\+|$')
   "Yes I am . But be able to toggle the fold flag on this filter I have to
   "know what project it belongs to so I can access it in the dictionary . for
   "this I have walk up the lines untill I find a '<projname>'
   
    let l:lnumber = line('.')-1
    while !(getline(l:lnumber)=~'\s*<.\+>$')
      " Keep going up until we hit a project name 
      let l:lnumber = l:lnumber-1
    endwhile
  "OK I think we're there , now lets shredd of any '|'s and '<>'s and toggle
  "the foldflag
      let l:projName = split(getline(l:lnumber),'[<> ]')[0]
      let l:filterName = split(l:file,'[| ]')[0]
      let s:wksDict[l:projName]['filters'][l:filterName]['fold'] = 1-s:wksDict[l:projName]['filters'][l:filterName]['fold'] 
      call s:DisplayDict()
      return
  endif

  " Ok so it must have been a filename. BUT we need to get at the relaitive
  " path name for this file and it is stored in the Dictionary keys under
  " project name and filter. We have work up the buffer a line at a time to get
  " the fiter name AND the project name

  let l:filter=' '
  let l:lnumber = line('.')-1
  while !(getline(l:lnumber)=~'\s*<.\+>$')
  " Keep going up until either we hit a project name .. but in the proces if we
  " hit a filter name better keep hold og it
    if (getline(l:lnumber)=~'\s*|.\+|$') && l:filter==' ' 
      let l:filter= split(getline(l:lnumber),'[| ]')[0]
    endif
    let l:lnumber = l:lnumber-1
  endwhile

  "Lets get rid of the angualr brackets from the project name
  let l:projName = split(getline(l:lnumber),'[<> ]')[0]
  
  "OK for bug fix  v0.33->0.33.1 this line has moved from  the line marked
                                  "****** BBBBBBugfix 0.33.1 to here
  exe "cd ".s:wksDirectory
  " we put the line above so it comes before setting l:projectPath
  " because if the filename we using with fnamemodify is not preappended by a
  " relative path l:projectpath automaticaly defaults to cwd, this caused
  " problems

  " and get the project path
  let l:projectPath = fnamemodify(s:wksDict[l:projName]['filename'],':p:h')

  "Lets cd to the workspace path from ther cd to the project path sice project
  "paths are relative to the workspace path
                                  "****** BBBBBBugfix 0.33.1 here 
  exe "cd ".l:projectPath
  "lets get the relative pathnamne of the file we are interestd in , it is
  "relative to the project file path hdenc we cd'd here 
  let l:fileName = s:wksDict[l:projName]['filters'][l:filter]['files'][l:file]
  " follwing three line are for debugging only
  "echo s:wksDirectory
  "echo l:projectPath
  "echo l:fileName
  
  
  " better be readable
  if filereadable(l:fileName)
    call WinManagerFileEdit(l:fileName ,a:split)
  else
     echo "Cannot open file :".l:file
  endif
  
  "lets cd back Although I am not sure if we ever get back here
  exe "cd ".l:cwd

endfunction


