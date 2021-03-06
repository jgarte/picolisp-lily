(load "../pond.l")

(class +MusicObj +Entity)
(rel id (+Need +Key +Number))
(rel nm (+Ref +String))

# REFACTOR
(rel l (+Blob))            # pl file
(rel ly (+Blob))           # ly file
(rel svg (+Blob))          # svg
(rel clean.svg (+Blob))    # 'sanitize>'d svg
(rel cropped.svg (+Blob))
(rel clean.cropped.svg (+Blob))
(rel preview.svg (+Blob))
(rel clean.preview.svg (+Blob))

# '+MusicObj' creator method
#
#   creates picolisp file with unique fn, e.g. 'test%1' (see 'blobFn')
(dm T ()
   (put!> This 'id (genKey 'id '+MusicObj))
   (put!> This 'l T)
   # put prototype in file
   (out (blob This 'l) (prin "(de " (blobFn This) " ())"))
   # load it
   (load (blob This 'l)) )

(de new-music () (new! '(+MusicObj)))

# edit picolisp file
(dm vi> ()
   (macro
      (vi (quote ^(list (blobFn This)))) )
   (load (blob This 'l)) )  # and reload it

# write lilypond file
(dm ly> ()
   (unless (: ly) (put!> This 'ly T))
   (out (blob This 'ly)
      # need to write variation of 'lilypond' here
      (lyVersion)
      (lyLayout)
      (lyInclude "lilyjazz.ily")
      (lyInclude "jazzchords.ly")
      ((blobFn This)) ) )  # call function in pl file

(dm echo> ()
   (in (blob This 'ly) (echo)) )

# render lilypond file to svg
(dm re> ()
   (unless (: svg) (put!> This 'svg T))
   (unless (: preview.svg) (put!> This 'preview.svg T))
   (t (call 'lilypond "-dcrop" "-dpreview" "-dbackend=svg" "-o" (blobDir This) (blob This 'ly))) )

#REFACTOR
# strip all '<a>' tags from svg files. lilypond links notes in svg to lines
# in the source file. not okay for sharing svg's on the internet, when the
# source files are +Blob's in the picolisp DB
#
# FIXME - this method makes a mess of the console. figure out way to mute
# output
(dm sanitize> ()
   (unless (: clean.svg) (put!> This 'clean.svg T))
   (let CleanSvg
      (in (blob This 'svg)
         (pack
            (make
               (while (line T)
                  # remove <a> tags from svg
                  (unless (or (pre? "<a" @) (pre? "</a>" @))
                     (link @) ) ) ) ) )
      (out (blob This 'clean.svg) (prin CleanSvg)) )
   (unless (: clean.preview.svg) (put!> This 'clean.preview.svg T))
   (let CleanPreviewSvg
      (in (blob This 'preview.svg)
         (prin
            (pack
               (make
                  (while (line T)
                     # remove <a> tags from svg
                     (unless (or (pre? "<a" @) (pre? "</a>" @))
                        (link @) ) ) ) ) ) )
      (out (blob This 'clean.preview.svg) (prin CleanPreviewSvg)) )
   (unless (: clean.cropped.svg) (put!> This 'clean.cropped.svg T))
   (let CleanCroppedSvg
         (in (blob This 'cropped.svg)
            (prin
               (pack
                  (make
                     (while (line T)
                        # remove <a> tags from svg
                        (unless (or (pre? "<a" @) (pre? "</a>" @))
                           (link @) ) ) ) ) ) )
         (out (blob This 'clean.cropped.svg) (prin CleanCroppedSvg)) ) )

# send updated SVG to the browser
(dm send> ()
   (let @Sse (any (pack "*Obj" (: id)))
      (macro
         (serverSend @Sse
            (<MusicSVG> This) ) ) ) )

(de <MusicSVG> (Obj)
   # see https://stackoverflow.com/questions/1077041/refresh-image-with-a-new-one-at-the-same-url/9943419#9943419
   # '(date)' and '(time)' to fool browser cache and update image
   (<img> (pack "http://localhost:8080/" (blob Obj 'clean.cropped.svg) "#" (date) (time))) )

(dm work> ()
   (vi> This)
   (ly> This)
   (re> This)
   # (cl> This)
   (sanitize> This)
   (send> This) )

# start a new project or change to an existing project
#
# each project is a directory, with a db file and +Blob's
(de stitch (Name)
   (let (Pool (pack "db/" Name "/" Name ".db")
         Blob (pack "db/" Name "/") )
      (setq
         *Pool Pool
         *Blob Blob )
      (call "mkdir" "-p" *Blob)
      (pool *Pool) ) )

(setq
   *Pool "db/test/test.db"
   *Blob "db/test/" )

(de main ()
   (call "mkdir" "-p" *Blob)
   (pool *Pool *Dbs)
   # load +MusicObj's
   (for Obj (collect 'id '+MusicObj) (load (blob Obj 'l))) )

(de go () (server 8080 "!work"))

(load "@lib/http.l" "@lib/xhtml.l")

(de work ()
   (app)
   (timeout)
   (redirect (baseHRef) *SesId "!musicApp") )

(de musicApp ()
   (html 0 "music app" NIL NIL
      (<ping> 7)
      (<ProjectHeader>)
      (setupServerEvents)
      (collectMusicObjs)
      (interactJS) ) )

(de <ProjectHeader> ()
   (let Prj (pack (car (split (chop (blobFn)) "%")))  # current (default/test) project on app start
      # (serverSentEvent "project" '*Project)
      (<h1> '(id . "project")
         "Project: " Prj) ) )

# server sent event for each +MusicObj
(de setupServerEvents ()
   (for Obj (collect 'id '+MusicObj)
      (serverSentEvent
         (sseId> Obj)
         (sseVar> Obj) ) ) )

# sse helpers, e.g. *SsEvt -> (("obj3" *Obj3) ... )
(dm sseVar> () (any (pack "*Obj" (: id))))
(dm sseId>  () (pack "obj" (: id)))  # connects to <div> from 'collectMusicObjs'

# <div> containing svg for each +MusicObj
(de collectMusicObjs ()
   (for Obj (collect 'id '+MusicObj)
      (<MusicDiv> Obj) ) )

(de <MusicDiv> (Obj)
   (let Name (; Obj nm)
      (<div>
         (list 'drag  # connect to 'interact.js'
            (cons 'id (sseId> Obj))  # connect to sse
            '(style . "width: min-content;") )
         (<h4> NIL Name)
         (<MusicSVG> Obj) ) ) )

(push '*JS "interact.min.js")

(de interactJS ()
   (<javascript>
      "interact('.drag').draggable({
         listeners: {
            move: dragMoveListener
         },
         autoScroll: true
      })
      function dragMoveListener (event) {
         var target = event.target
         var x = (parseFloat(target.getAttribute('data-x')) || 0) + event.dx
         var y = (parseFloat(target.getAttribute('data-y')) || 0) + event.dy
         target.style.transform = 'translate(' + x + 'px, ' + y + 'px)'
         target.setAttribute('data-x', x)
         target.setAttribute('data-y', y)
      }" ) )

### utils

# return list of all +MusicObjs with (optional) names
(de musicObjs ()
   (make
      (for Obj (collect 'id '+MusicObj)
         (link
            (list Obj (if (; Obj nm) @)) ) ) ) )

# list projects
(de projects () (chdir "db/" (dir)))

# returns blob subdirectory
# (blobDir '{A1}) -> "db/blob/A/"
# (blobDir '{2}) -> "db/blob/"
(de blobDir (Obj)
   (pack
      (glue "/"
         (filter '((X) (not (num? (any (car X)))))
            (split (chop (blob Obj)) "/") ) )
      "/" ) )

# returns fn from +MusicObj
(de blobFn (Obj)
   (and (blobDir Obj)
      (chop @)
      (split @ "/" ".")
      (pack (cdr @) "%" (; Obj id))
      (any @) ) )  # -> e.g. test%1 (project%id)

NIL
###
# the following was an attempt to dynamically add server events after the app is running
# i've decided it's a waste of time for now

(de serverSentEvent+ (Id Var . Prg)
# same as 'serverSentEvent' but uses 'insertAdjacentHTML' instead of 'innerHTML'
# used to add new events to the document AFTER the document has loaded
###
   (allow "!ssEvt")
   (<javascript>
      "(new EventSource(SesId+'!ssEvt?'+'"
      Id
      "')).onmessage = function(ev) {if (ev.data.charAt(0) == '&') document.title = ev.data.substr(1); else document.getElementById('"
      Id
      "').insertAdjacentHTML = ('beforeend', ev.data);}" )
   (if (assoc Id *SsEvts)
      (con @ (cons Var (unless (val Var) Prg)))
      (push '*SsEvts (cons Id Var Prg)) ) )

(de serverSentEvent+js (Id Var . Prg)
# FIXME - attempt to insert/execute script into dom, to dynamically add server
# events after the app is running. 'serverSentEvent+' is not sufficient because
# the browser will not run <script>'s created with
# innerHTML/insertAdjacentHTML. need to do something like:
#
#    var newScript = document.createElement('script')
#    newScript.text = script text goes here
#    document.getElementById('id').append(newScript)
   (allow "!ssEvt")
   (<javascript>
      "(new EventSource(SesId+'!ssEvt?'+'" Id "')).onmessage = function(ev) {
         if (ev.data.charAt(0) == '&') {
            document.title = ev.data.substr(1);
         } else {
            var newScript = document.createElement('script');
            newScript.text = ev.data;
            document.getElementById('" Id "').appendChild(newScript);
         }
      }" )
   (if (assoc Id *SsEvts)
      (con @ (cons Var (unless (val Var) Prg)))
      (push '*SsEvts (cons Id Var Prg)) ) )
