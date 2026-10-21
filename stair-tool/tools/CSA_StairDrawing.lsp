;;; Generated standalone CSA Stair Drawing; do not edit this bundle.
;;; Source: tools/CSA_StairStandardsTest.lsp + ui/CSA_StairDrawing.core.lsp
;;; CSA Stair: native standards acceptance test, AutoCAD Windows.
;;; APPLOAD this file. Commands: CSA_STAIR_CHECK / CSA_STAIR_TEST /
;;; CSA_STAIR_TEST_CLEAR. Uses definitions in the current drawing only.
;;; No existing layer/style/block definitions are created or overwritten.
(vl-load-com)

(defun csast:layers ()
  '("06-GB-Slab-bor" "21-GB-BD" "04-GB-Dim" "10-GB-Text"
    "11-GB-Cao Do" "12-GB-Ky Hieu" "18-GB-Reinf" "20-GB-GC"))

(defun csast:blocks ()
  '(("Cao do" "%%P0.000") ("Daucat" "A")
    ("So hieu thep" "A") ("CSA_Sohieu-KCthep" "SH" "DK-KC")))

(defun csast:tags (name / d e tags)
  (setq d (tblsearch "BLOCK" name) e (cdr (assoc -2 d)))
  (while e
    (setq d (entget e))
    (cond ((= "ENDBLK" (cdr (assoc 0 d))) (setq e nil))
          (T (if (= "ATTDEF" (cdr (assoc 0 d)))
               (setq tags (cons (strcase (cdr (assoc 2 d))) tags)))
             (setq e (entnext e)))))
  tags)

(defun csast:missing (/ issues name spec tag tags)
  (foreach name (csast:layers)
    (if (not (tblsearch "LAYER" name))
      (setq issues (cons (strcat "Missing layer: " name) issues))))
  (foreach name '("01-GB-Arial" "02-GB-VNI-Helve")
    (if (not (tblsearch "STYLE" name))
      (setq issues (cons (strcat "Missing text style: " name) issues))))
  (foreach spec (csast:blocks)
    (if (not (tblsearch "BLOCK" (car spec)))
      (setq issues (cons (strcat "Missing block: " (car spec)) issues))
      (progn
        (setq tags (csast:tags (car spec)))
        (foreach tag (cdr spec)
          (if (not (member (strcase tag) tags))
            (setq issues (cons (strcat "Missing tag: " (car spec) " / " tag) issues)))))))
  (reverse issues))

(defun csast:report (issues / x)
  (if issues
    (foreach x issues (princ (strcat "\n" x)))
    (princ "\nCSA resources found. Definitions and fonts have not been modified.")))

(defun c:CSA_STAIR_CHECK (/ name style font dims d)
  (csast:report (csast:missing))
  (princ (strcat "\nINSUNITS=" (itoa (getvar "INSUNITS")) " (4 = mm)."))
  (foreach name '("01-GB-Arial" "02-GB-VNI-Helve")
    (if (setq style (tblsearch "STYLE" name))
      (progn
        (setq font (cdr (assoc 3 style)))
        (princ (strcat "\nFont " name ": " (if font font "<unspecified>")))
        (if (and font (not (findfile font)))
          (princ " [not found via AutoCAD search path; verify FONTALT/substitution]")))))
  (setq d (tblnext "DIMSTYLE" T))
  (princ "\nAvailable DimStyles:")
  (while d
    (princ (strcat "\n  " (cdr (assoc 2 d))))
    (setq d (tblnext "DIMSTYLE")))
  (princ))

(defun csast:pickstyle (/ names d file stream id result index answer)
  (setq d (tblnext "DIMSTYLE" T))
  (while d
    (setq names (cons (cdr (assoc 2 d)) names) d (tblnext "DIMSTYLE")))
  (setq names (acad_strlsort names))
  (if names
    (progn
      (setq file (vl-filename-mktemp "CSA_StairStyles" nil ".dcl")
            stream (open file "w"))
      (if stream
        (progn
          (write-line "csast_style : dialog { label = \"CSA Stair - Standards Test\"; : popup_list { key = \"styles\"; label = \"DimStyle\"; width = 52; } : text { label = \"Uses existing resources. Adds a removable test panel.\"; } ok_cancel; }" stream)
          (close stream)
          (setq id (load_dialog file))
          (if (and (> id 0) (new_dialog "csast_style" id))
            (progn
              (start_list "styles")
              (foreach d names (add_list d))
              (end_list)
              (setq index (vl-position (getvar "DIMSTYLE") names))
              (if (null index) (setq index 0))
              (set_tile "styles" (itoa index))
              (action_tile "accept" "(setq index (atoi (get_tile \"styles\"))) (done_dialog 1)")
              (setq result (start_dialog))
              (if (= result 1) (setq answer (nth index names)))))
          (if (> id 0) (unload_dialog id))))
      (if file (vl-file-delete file))))
  answer)

(defun csast:p (base x y)
  (list (+ (car base) x) (+ (cadr base) y) (caddr base)))

(defun csast:track (object / e d appname)
  ;; Track first so the error handler can remove even an untagged object.
  (setq csast-created (cons object csast-created))
  (vla-put-Color object 256)
  (vla-put-Linetype object "ByLayer")
  (vla-put-Lineweight object -1)
  (setq e (vlax-vla-object->ename object) d (entget e)
        appname (if (and (boundp 'csast-app) csast-app) csast-app "CSA_STAIR_STANDARDS_TEST"))
  (if (not (entmod (append d (list (list -3 (list appname (cons 1000 "v1")))))))
    (progn (princ "\nCannot mark the test entity.") (exit)))
  object)

(defun csast:line (space a b layer / o)
  (setq o (csast:track (vla-AddLine space (vlax-3d-point a) (vlax-3d-point b))))
  (vla-put-Layer o layer)
  o)

(defun csast:text (space value point height layer style / o)
  (setq o (csast:track (vla-AddText space value (vlax-3d-point point) height)))
  (vla-put-Layer o layer)
  (vla-put-StyleName o style)
  o)

(defun csast:insert (space name point layer scale values / o attrs att entry found)
  (setq o (csast:track (vla-InsertBlock space (vlax-3d-point point) name scale scale scale 0.0)))
  (vla-put-Layer o layer)
  (setq attrs (vlax-invoke o 'GetAttributes))
  ;; Tags, never attribute order, determine what gets written.
  (foreach att attrs
    (if (setq entry (assoc (strcase (vla-get-TagString att)) values))
      (progn (vla-put-TextString att (cdr entry))
             (setq found (cons (car entry) found)))))
  (foreach entry values
    (if (not (member (car entry) found))
      (progn
        (princ (strcat "\nNo editable attribute " name "/" (car entry)))
        (exit))))
  (vla-Update o)
  o)

(defun c:CSA_STAIR_TEST (/ *error* doc space issues style base height
                         ds name ld csast-created undo-started o item)
  (defun *error* (msg)
    (foreach item csast-created (vl-catch-all-apply 'vla-Delete (list item)))
    (if undo-started (vl-catch-all-apply 'vla-EndUndoMark (list doc)))
    (if msg (princ (strcat "\nTest stopped: " msg)))
    (princ "\nPartial test geometry removed. Existing definitions unchanged.")
    (princ))
  (setq issues (csast:missing))
  ;; The command adds model-space entities. Do not surprise layout users.
  (if (/= (getvar "TILEMODE") 1)
    (setq issues (cons "Switch to the Model tab before testing." issues)))
  (if (/= (getvar "INSUNITS") 4)
    (setq issues (cons "This test requires INSUNITS=4 (millimeters)." issues)))
  (foreach name (csast:layers)
    (if (setq ld (tblsearch "LAYER" name))
      (if (or (/= 0 (logand 5 (cdr (assoc 70 ld))))
              (< (cdr (assoc 62 ld)) 0))
        (setq issues (cons (strcat "Layer off/frozen/locked: " name) issues)))))
  (csast:report issues)
  (if (and (not issues) (setq style (csast:pickstyle))
           (setq base (getpoint "\nPick test-panel insertion point: ")))
    (progn
      (setq base (trans base 1 0)
            doc (vla-get-ActiveDocument (vlax-get-acad-object))
            space (vla-get-ModelSpace doc)
            ds (tblsearch "DIMSTYLE" style)
            height (* (cond ((cdr (assoc 140 ds))) (T 2.5))
                      (cond ((cdr (assoc 40 ds))) (T 1.0))))
      (if (<= height 0.0) (setq height 62.5))
      (vla-StartUndoMark doc) (setq undo-started T)
      (regapp "CSA_STAIR_STANDARDS_TEST")
      (csast:text space (strcat "CSA STAIR TEST | DIMSTYLE: " style)
        (csast:p base 0 1600) height "10-GB-Text" "01-GB-Arial")
      (csast:text space "Test only - not a staircase drawing or rebar design"
        (csast:p base 0 1300) height "10-GB-Text" "01-GB-Arial")
      (csast:line space (csast:p base 0 0) (csast:p base 3000 0) "21-GB-BD")
      (csast:line space (csast:p base 3000 0) (csast:p base 3000 200) "21-GB-BD")
      (csast:line space (csast:p base 3000 200) (csast:p base 0 200) "21-GB-BD")
      (csast:line space (csast:p base 0 200) base "21-GB-BD")
      (csast:line space (csast:p base 100 60) (csast:p base 2900 60) "18-GB-Reinf")
      (setq o (csast:track (vla-AddDimAligned space
        (vlax-3d-point base) (vlax-3d-point (csast:p base 3000 0))
        (vlax-3d-point (csast:p base 1500 -500)))))
      (vla-put-Layer o "04-GB-Dim")
      (vla-put-StyleName o style)
      (csast:insert space "Cao do" (csast:p base 0 200) "11-GB-Cao Do" 0.25
        '(("%%P0.000" . "+3.600")))
      (csast:insert space "Daucat" (csast:p base 4000 0) "12-GB-Ky Hieu" 0.0075
        '(("A" . "1-1")))
      (csast:insert space "So hieu thep" (csast:p base 0 -1700) "20-GB-GC" 0.35
        '(("A" . "1")))
      (csast:insert space "CSA_Sohieu-KCthep" (csast:p base 3000 -1700) "20-GB-GC" 1.0
        '(("SH" . "2") ("DK-KC" . "12a150")))
      (csast:text space "CSA FONT SAMPLE: 12a150 / ST-01 / +3.600"
        (csast:p base 0 -2500) height "10-GB-Text" "02-GB-VNI-Helve")
      (vla-Regen doc 0)
      (vla-EndUndoMark doc) (setq undo-started nil)
      (princ (strcat "\nTest panel created. DimStyle: " style
        "; block scales fixed: Cao do=0.25, Daucat=0.0075, mark=0.35, note=1.0"
        ". Check dimension=3000, block shape/scale, font and colors."))
      (princ "\nRun CSA_STAIR_TEST_CLEAR to remove only tagged test objects.")))
  (princ))

(defun c:CSA_STAIR_TEST_CLEAR (/ *error* doc ss i count started)
  (defun *error* (msg)
    (if started (vl-catch-all-apply 'vla-EndUndoMark (list doc)))
    (if msg (princ (strcat "\nCleanup stopped: " msg)))
    (princ))
  (setq ss (ssget "_X" '((410 . "Model") (-3 ("CSA_STAIR_STANDARDS_TEST"))))
        count 0)
  (if ss
    (progn
      (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)) i 0)
      (vla-StartUndoMark doc) (setq started T)
      (repeat (sslength ss)
        (if (entdel (ssname ss i)) (setq count (1+ count)))
        (setq i (1+ i)))
      (vla-EndUndoMark doc) (setq started nil)))
  (princ (strcat "\nRemoved " (itoa count) " CSA test objects. Other geometry retained."))
  (princ))

(princ "\nCSA loaded: CSA_STAIR_CHECK, CSA_STAIR_TEST, CSA_STAIR_TEST_CLEAR.")
(princ)

;;; Bundled after the standards helpers by tools/build_stair_bundle.py.
;;; A section-only UI for the existing workbook's BY/BZ/CA coordinate contract.

(defun csad:get (key) (cdr (assoc key *csad-state*)))
(defun csad:put (key value / entry)
  (setq entry (assoc key *csad-state*))
  (if entry (setq *csad-state* (subst (cons key value) entry *csad-state*))
    (setq *csad-state* (cons (cons key value) *csad-state*)))
  value)

(defun csad:cell (cells row col / cell value kind)
  (setq cell (csad:unwrap (vlax-get-property cells 'Item row col))
        value (vlax-get-property cell 'Value2))
  (vlax-release-object cell)
  (if (= (type value) 'VARIANT)
    (progn
      (setq kind (vlax-variant-type value))
      (if (= kind 10)
        (progn (princ (strcat "\nExcel error at row " (itoa row) ", column " (itoa col))) (exit)))
      (setq value (vlax-variant-value value))))
  value)

(defun csad:unwrap (value)
  (if (= (type value) 'VARIANT) (vlax-variant-value value) value))

(defun csad:cleanpoints (points / result p firstp)
  (foreach p points
    (if (or (null result) (> (distance p (car result)) 0.000001))
      (setq result (cons p result))))
  (setq result (reverse result) firstp (car result))
  (if (and (> (length result) 1) (< (distance firstp (last result)) 0.000001))
    (setq result (reverse (cdr (reverse result)))))
  result)

(defun csad:area (points / area p q looppts)
  (setq area 0.0 looppts (append points (list (car points))))
  (while (cdr looppts)
    (setq p (car looppts) q (cadr looppts)
          area (+ area (- (* (car p) (cadr q)) (* (car q) (cadr p))))
          looppts (cdr looppts)))
  (/ (abs area) 2.0))

(defun csad:loadexcel (path / *error* excel books book sheets sheet cells row id x y candidate ref
                           points rawcount rise bottom title firstlevel high found)
  (defun *error* (msg)
    (foreach ref (list cells sheet sheets book books excel)
      (if (= (type ref) 'VLA-OBJECT) (vl-catch-all-apply 'vlax-release-object (list ref))))
    (if msg (princ (strcat "\nExcel load stopped: " msg)))
    (alert "Cannot read coordinates. Open the selected workbook in Excel and check BY/BZ/CA for errors. Previous loaded data is retained.")
    (princ))
  ;; Attach only: never create/quit Excel, close workbooks, enable macros,
  ;; write cells or force recalculation in the user's running session.
  (setq excel (vlax-get-object "Excel.Application") books (csad:unwrap (vlax-get-property excel 'Workbooks)))
  (vlax-for candidate books
    (if (= (strcase (vlax-get-property candidate 'FullName)) (strcase path))
      (setq found candidate)))
  (if (not found)
    (progn (princ "\nThe selected workbook is not open in the attached Excel instance.") (exit)))
  (setq book found sheets (csad:unwrap (vlax-get-property book 'Worksheets))
        sheet (csad:unwrap (vlax-get-property sheets 'Item "Cau Thang Tools"))
        cells (csad:unwrap (vlax-get-property sheet 'Cells)) row 2 points nil rawcount 0
        id (csad:cell cells row 77))
  (while (and (<= row 500) id (not (equal id "")))
    (setq x (csad:cell cells row 78) y (csad:cell cells row 79))
    (if (not (and (numberp id) (numberp x) (numberp y)))
      (progn (princ (strcat "\nInvalid STT/X/Y at row " (itoa row))) (exit)))
    (setq points (cons (list (float x) (float y)) points)
          rawcount (1+ rawcount) row (1+ row) id (csad:cell cells row 77)))
  (if (and id (not (equal id "")))
    (progn (princ "\nCoordinate table exceeds row 500.") (exit)))
  (setq points (csad:cleanpoints (reverse points)))
  (if (or (< (length points) 3) (< (csad:area points) 0.000001))
    (progn (princ "\nCoordinate outline is empty or degenerate.") (exit)))
  (setq rise (csad:cell cells 22 4) bottom (csad:cell cells 30 13)
        title (csad:cell cells 33 30) firstlevel (cadar points)
        high (apply 'max (mapcar 'cadr points)))
  (if (= (type bottom) 'STR) (setq bottom (distof bottom 2)))
  (if (not (and (numberp rise) (> rise 0) (numberp bottom)
                (< (abs (- rise (- high firstlevel))) 0.5)))
    (progn (princ "\nD22/M30 or the floor-level geometry does not match this workbook contract.") (exit)))
  (csad:put 'points points)
  (csad:put 'path path)
  (csad:put 'bottom (csad:fixed3 bottom))
  (csad:put 'top (csad:fixed3 (+ bottom (/ rise 1000.0))))
  (if (and (= (type title) 'STR) (/= title "")) (csad:put 'title title))
  (csad:put 'status (strcat (itoa rawcount) " Excel rows / " (itoa (length points))
    " vertices loaded. Reload after Excel changes."))
  (foreach ref (list cells sheet sheets book books excel)
    (if (= (type ref) 'VLA-OBJECT) (vlax-release-object ref)))
  T)

(defun csad:capture (/ key)
  (foreach key '("title" "section" "bottom" "top" "dims" "levels" "symbol")
    (csad:put (read key) (get_tile key)))
  (csad:put 'dimstyle (nth (atoi (get_tile "dimstyle")) csad-styles)))

(defun csad:dialog (/ file f id answer name entry index csad-styles line)
  (setq entry (tblnext "DIMSTYLE" T))
  (while entry
    (setq csad-styles (cons (cdr (assoc 2 entry)) csad-styles) entry (tblnext "DIMSTYLE")))
  (setq csad-styles (acad_strlsort csad-styles)
        file (vl-filename-mktemp "CSA_StairDrawing" nil ".dcl") f (open file "w"))
  (if f
    (progn
      (foreach line
        '("csad_ui : dialog { label = \"CSA TOOLS | Stair Drawing\";"
          ": boxed_column { label = \"Excel source - existing section coordinates\";"
          ": text { key = \"path\"; width = 80; }"
          ": button { key = \"load\"; label = \"Load / Reload Excel...\"; } }"
          ": row { : boxed_column { label = \"Drawing parameters\";"
          ": edit_box { key = \"title\"; label = \"Stair name\"; edit_width = 24; }"
          ": edit_box { key = \"section\"; label = \"Section ID\"; edit_width = 24; }"
          ": popup_list { key = \"dimstyle\"; label = \"DimStyle\"; width = 42; }"
          ": edit_box { key = \"bottom\"; label = \"Bottom elevation (m)\"; edit_width = 16; }"
          ": edit_box { key = \"top\"; label = \"Top elevation (m)\"; edit_width = 16; } }"
          ": boxed_column { label = \"Accepted CSA block scales\";"
          ": text { label = \"Cao do : 0.25\"; }"
          ": text { label = \"Daucat : 0.0075\"; }"
          ": text { label = \"So hieu thep : 0.35\"; }"
          ": text { label = \"CSA_Sohieu-KCthep : 1.0\"; }"
          ": text { label = \"Preview in the AutoCAD viewport\"; } } }"
          ": boxed_row { label = \"Section options\";"
          ": toggle { key = \"dims\"; label = \"Overall dimensions\"; }"
          ": toggle { key = \"levels\"; label = \"Elevations\"; }"
          ": toggle { key = \"symbol\"; label = \"Section symbol\"; } }"
          ": text { key = \"status\"; width = 80; }"
          ": row { : button { key = \"preview\"; label = \"Preview\"; }"
          ": button { key = \"draw\"; label = \"Draw Section\"; }"
          ": button { key = \"plan\"; label = \"Plan (next phase)\"; }"
          ": button { key = \"clear\"; label = \"Clear Preview\"; }"
          ": button { key = \"cancel\"; label = \"Close\"; is_cancel = true; } } }")
        (write-line line f))
      (close f)
      (setq id (load_dialog file))
      (if (and (> id 0) (new_dialog "csad_ui" id))
        (progn
          (set_tile "path" (cond ((csad:get 'path)) (T "Open workbook in Excel, then Load Excel.")))
          (foreach name '("title" "section" "bottom" "top" "dims" "levels" "symbol" "status")
            (set_tile name (csad:get (read name))))
          (start_list "dimstyle") (foreach name csad-styles (add_list name)) (end_list)
          (setq index (vl-position (csad:get 'dimstyle) csad-styles))
          (if (null index) (setq index 0))
          (set_tile "dimstyle" (itoa index))
          (mode_tile "plan" 1)
          (if (not (csad:get 'points)) (progn (mode_tile "preview" 1) (mode_tile "draw" 1)))
          (action_tile "load" "(csad:capture) (done_dialog 11)")
          (action_tile "preview" "(csad:capture) (done_dialog 12)")
          (action_tile "draw" "(csad:capture) (done_dialog 13)")
          (action_tile "clear" "(csad:capture) (done_dialog 14)")
          (action_tile "cancel" "(csad:capture) (done_dialog 0)")
          (setq answer (start_dialog))))
      (if (> id 0) (unload_dialog id))))
  (if file (vl-file-delete file))
  (if (null answer) (alert "Cannot open the CSA dialog. Check DCL diagnostics in command history (F2)."))
  answer)

(defun csad:owned (/ ss i result)
  (setq ss (ssget "_X" '((410 . "Model") (-3 ("CSA_STAIR_PREVIEW")))) i 0)
  (if ss (repeat (sslength ss) (setq result (cons (ssname ss i) result) i (1+ i))))
  result)

(defun csad:layerready (name / d)
  (setq d (tblsearch "LAYER" name))
  (and d (= 0 (logand 5 (cdr (assoc 70 d)))) (> (cdr (assoc 62 d)) 0)))

(defun csad:clean (/ old e okay)
  (setq old (csad:owned) okay T)
  (foreach e old
    (if (not (csad:layerready (cdr (assoc 8 (entget e))))) (setq okay nil)))
  (if okay
    (progn (foreach e old (entdel e)) (csad:put 'status "Owned preview removed; final drawing retained."))
    (alert "A previous preview is on an off/frozen/locked layer. Preview was retained.")))

(defun csad:fixed3 (value / result dot)
  ;; rtos respects DIMZIN. Normalize to exactly three fractional digits
  ;; without changing the user's dimension settings.
  (setq result (rtos value 2 3))
  (if (= (substr result 1 1) ".") (setq result (strcat "0" result)))
  (if (= (substr result 1 2) "-.") (setq result (strcat "-0" (substr result 2))))
  (setq dot (vl-string-search "." result))
  (if (null dot) (setq result (strcat result ".000"))
    (while (< (- (strlen result) dot 1) 3) (setq result (strcat result "0"))))
  result)

(defun csad:leveltext (value)
  (strcat (if (>= value 0.0) "+" "") (csad:fixed3 value)))

(defun csad:render (preview / *error* points base doc space csast-created csast-app
                            started old e layer coords array pl o minx maxx miny maxy
                            height ds p toppt bottom top need name issue entities)
  (defun *error* (msg)
    (foreach o csast-created (vl-catch-all-apply 'vla-Delete (list o)))
    (if started (vl-catch-all-apply 'vla-EndUndoMark (list doc)))
    (if msg (princ (strcat "\nSection stopped: " msg)))
    (alert "Section operation stopped. Check the command history (F2).")
    (princ))
  (setq points (csad:get 'points) bottom (distof (csad:get 'bottom) 2)
        top (distof (csad:get 'top) 2) old (csad:owned))
  (if (or (null bottom) (null top) (<= top bottom))
    (setq issue "Enter valid elevations with top above bottom."))
  (if (and points bottom top
      (> (abs (- (* 1000.0 (- top bottom))
                 (- (apply 'max (mapcar 'cadr points)) (cadar points)))) 0.5))
    (setq issue "Elevation difference must match the loaded section height (within 0.5 mm)."))
  (if (or (/= (getvar "TILEMODE") 1) (/= (getvar "INSUNITS") 4))
    (setq issue "Use Model tab with INSUNITS=4 (mm)."))
  (if (not (tblsearch "DIMSTYLE" (csad:get 'dimstyle))) (setq issue "Selected DimStyle is missing."))
  (setq need (if preview '("CSA-PREVIEW") '("21-GB-BD" "10-GB-Text")))
  (if (not preview)
    (progn
      (if (= "1" (csad:get 'dims)) (setq need (cons "04-GB-Dim" need)))
      (if (= "1" (csad:get 'levels)) (setq need (cons "11-GB-Cao Do" need)))
      (if (= "1" (csad:get 'symbol)) (setq need (cons "12-GB-Ky Hieu" need)))))
  (foreach name need
    (if (and (not (and preview (= name "CSA-PREVIEW") (not (tblsearch "LAYER" name))))
             (not (csad:layerready name)))
      (setq issue (strcat "Missing, off, frozen or locked layer: " name))))
  (if (not (tblsearch "STYLE" "01-GB-Arial")) (setq issue "Missing text style: 01-GB-Arial"))
  (foreach name (if (= "1" (csad:get 'levels)) '("Cao do") nil)
    (if (not (member "%%P0.000" (csast:tags name))) (setq issue "Missing block/tag: Cao do/%%P0.000")))
  (if (and (= "1" (csad:get 'symbol)) (not (member "A" (csast:tags "Daucat"))))
    (setq issue "Missing block/tag: Daucat/A"))
  (foreach e old
    (if (not (csad:layerready (cdr (assoc 8 (entget e)))))
      (setq issue "Old preview layer is off, frozen or locked.")))
  (if issue (alert issue)
    (if (setq base (getpoint (if preview "\nPick section preview origin: " "\nPick final section origin: ")))
      (progn
        (setq base (trans base 1 0)
              doc (vla-get-ActiveDocument (vlax-get-acad-object)) space (vla-get-ModelSpace doc)
              csast-app (if preview "CSA_STAIR_PREVIEW" "CSA_STAIR_FINAL")
              layer (if preview "CSA-PREVIEW" "21-GB-BD"))
        (vla-StartUndoMark doc) (setq started T)
        (if (not (tblsearch "LAYER" layer))
          (progn (setq o (vla-Add (vla-get-Layers doc) layer))
                 (vla-put-Color o 4) (vla-put-Plottable o :vlax-false)))
        (regapp csast-app)
        (setq minx (apply 'min (mapcar 'car points)) maxx (apply 'max (mapcar 'car points))
              miny (apply 'min (mapcar 'cadr points)) maxy (apply 'max (mapcar 'cadr points))
              toppt (car (vl-member-if '(lambda (p) (= (cadr p) maxy)) points))
              ds (tblsearch "DIMSTYLE" (csad:get 'dimstyle))
              height (* (cond ((cdr (assoc 140 ds))) (T 2.5))
                        (cond ((cdr (assoc 40 ds))) (T 1.0))))
        (if (<= height 0) (setq height 62.5))
        (foreach p points
          (setq coords (append coords (list (+ (car base) (car p)) (+ (cadr base) (cadr p))))))
        (setq array (vlax-make-safearray vlax-vbDouble (cons 0 (1- (length coords)))))
        (vlax-safearray-fill array coords)
        (setq pl (csast:track (vla-AddLightWeightPolyline space array)))
        (vla-put-Layer pl layer) (vla-put-Closed pl :vlax-true) (vla-put-Elevation pl (caddr base))
        (csast:text space (csad:get 'title) (csast:p base minx (- miny 1000)) height
          (if preview layer "10-GB-Text") "01-GB-Arial")
        (if (= "1" (csad:get 'dims))
          (foreach p (list
            (list (csast:p base minx miny) (csast:p base maxx miny)
                  (csast:p base (/ (+ minx maxx) 2.0) (- miny 500)))
            (list (csast:p base maxx miny) (csast:p base maxx maxy)
                  (csast:p base (+ maxx 500) (/ (+ miny maxy) 2.0))))
            (setq o (csast:track (vla-AddDimAligned space
              (vlax-3d-point (car p)) (vlax-3d-point (cadr p)) (vlax-3d-point (caddr p)))))
            (vla-put-Layer o (if preview layer "04-GB-Dim"))
            (vla-put-StyleName o (csad:get 'dimstyle))))
        (if (= "1" (csad:get 'levels))
          (progn
            (csast:insert space "Cao do" (csast:p base (caar points) (cadar points))
              (if preview layer "11-GB-Cao Do") 0.25 (list (cons "%%P0.000" (csad:leveltext bottom))))
            (csast:insert space "Cao do" (csast:p base (car toppt) (cadr toppt))
              (if preview layer "11-GB-Cao Do") 0.25 (list (cons "%%P0.000" (csad:leveltext top))))))
        (if (= "1" (csad:get 'symbol))
          (csast:insert space "Daucat" (csast:p base minx (- miny 1400))
            (if preview layer "12-GB-Ky Hieu") 0.0075 (list (cons "A" (csad:get 'section)))))
        ;; Replace only previously tagged previews after new geometry succeeds.
        (foreach e old (if (not (entdel e)) (progn (princ "\nCannot delete old preview.") (exit))))
        (vla-Regen doc 0) (vla-EndUndoMark doc) (setq started nil)
        (csad:put 'status (if preview "Section preview updated. Final geometry retained."
                           "Section drawn on CSA layers. Preview removed."))
        (princ (strcat "\n" (csad:get 'status))))))
  (princ))

(defun c:CSA_STAIR_DRAWING (/ action path)
  (if (not (boundp '*csad-state*))
    (setq *csad-state* '((title . "ST-01") (section . "1-1") (dimstyle . "GB 25")
      (bottom . "0.000") (top . "0.000") (dims . "1") (levels . "1") (symbol . "1")
      (status . "Load current Excel coordinates to begin."))))
  (setq action 1)
  (while (and action (/= action 0))
    (setq action (csad:dialog))
    (cond
      ((and action (= action 11))
        (if (setq path (getfiled "Select the workbook already open in Excel" "" "xlsm" 0))
          (csad:loadexcel path)))
      ((and action (= action 12)) (csad:render T) (setq action 0))
      ((and action (= action 13)) (csad:render nil) (setq action 0))
      ((and action (= action 14)) (csad:clean))))
  (princ "\nRun CSA_STAIR_DRAWING to reopen. Loaded coordinates are a snapshot; reload after Excel edits.")
  (princ))

(princ "\nCSA Stair UI loaded. Run CSA_STAIR_DRAWING.")
(princ)
