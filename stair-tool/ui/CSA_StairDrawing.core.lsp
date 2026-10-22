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
                           points rawpoints metadata rawcount rise bottom title firstlevel high found)
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
    (if (not (and (numberp id) (= id (1+ rawcount)) (numberp x) (numberp y)))
      (progn (princ (strcat "\nInvalid STT/X/Y at row " (itoa row))) (exit)))
    (setq points (cons (list (float x) (float y)) points)
          rawcount (1+ rawcount) row (1+ row) id (csad:cell cells row 77)))
  (if (and id (not (equal id "")))
    (progn (princ "\nCoordinate table exceeds row 500.") (exit)))
  (setq rawpoints (reverse points) points (csad:cleanpoints rawpoints))
  (if (or (< (length points) 3) (< (csad:area points) 0.000001))
    (progn (princ "\nCoordinate outline is empty or degenerate.") (exit)))
  (setq rise (csad:cell cells 22 4) bottom (csad:cell cells 30 13)
        title (csad:cell cells 33 30) firstlevel (cadar points)
        high (apply 'max (mapcar 'cadr points)))
  (if (= (type bottom) 'STR) (setq bottom (distof bottom 2)))
  (if (not (and (numberp rise) (> rise 0) (numberp bottom)
                (< (abs (- rise (- high firstlevel))) 0.5)))
    (progn (princ "\nD22/M30 or the floor-level geometry does not match this workbook contract.") (exit)))
  (setq metadata (list (csad:cell cells 19 8) (csad:cell cells 19 26)
    (csad:cell cells 19 53) (csad:cell cells 31 4) (csad:cell cells 33 4)
    (csad:cell cells 21 73) (csad:cell cells 22 73) (csad:cell cells 27 41)))
  (csad:put 'rawpoints rawpoints)
  (csad:put 'concrete-parameters metadata)
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
  (foreach key '("title" "section" "bottom" "top" "dims" "details" "levels" "symbol" "titleheight" "dimgap")
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
          ": row { : edit_box { key = \"titleheight\"; label = \"Title height (mm)\"; edit_width = 12; }"
          ": edit_box { key = \"dimgap\"; label = \"Dimension spacing (mm)\"; edit_width = 12; } }"
          ": boxed_row { label = \"Section options\";"
          ": toggle { key = \"dims\"; label = \"Overall dimensions\"; }"
          ": toggle { key = \"details\"; label = \"Concrete details\"; }"
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
          (foreach name '("title" "section" "bottom" "top" "dims" "details" "levels" "symbol" "status" "titleheight" "dimgap")
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
                            height titleheight gap specs spec ds p toppt bottom top need name issue entities)
  (defun *error* (msg)
    (foreach o csast-created (vl-catch-all-apply 'vla-Delete (list o)))
    (if started (vl-catch-all-apply 'vla-EndUndoMark (list doc)))
    (if msg (princ (strcat "\nSection stopped: " msg)))
    (alert "Section operation stopped. Check the command history (F2).")
    (princ))
  (setq points (csad:get 'points) bottom (distof (csad:get 'bottom) 2)
        top (distof (csad:get 'top) 2) old (csad:owned)
        titleheight (distof (csad:get 'titleheight) 2) gap (distof (csad:get 'dimgap) 2))
  (if (or (null titleheight) (null gap)
          (and titleheight (<= titleheight 0.0)) (and gap (<= gap 0.0)))
    (setq issue "Title height and dimension spacing must be positive numbers."))
  (if (= "1" (csad:get 'details))
    (if (setq spec (csad:detail-error (csad:get 'rawpoints) (csad:get 'concrete-parameters)))
      (setq issue spec)))
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
      (if (or (= "1" (csad:get 'dims)) (= "1" (csad:get 'details)))
        (setq need (cons "04-GB-Dim" need)))
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
        (csad:caption space base minx maxx miny titleheight gap preview)
        (if (= "1" (csad:get 'dims))
          (foreach spec (list
            (list "overall_width" "H" (list minx miny) (list maxx miny)
                  (list (/ (+ minx maxx) 2.0) (- miny (* 2.0 gap))))
            (list "overall_height" "V" (list maxx miny) (list maxx maxy)
                  (list (+ maxx (* 3.0 gap)) (/ (+ miny maxy) 2.0))))
            (csad:draw-spec space base spec (if preview layer "04-GB-Dim") (csad:get 'dimstyle))))
        (if (= "1" (csad:get 'details))
          (foreach spec (csad:detail-specs (csad:get 'rawpoints) gap)
            (csad:draw-spec space base spec (if preview layer "04-GB-Dim") (csad:get 'dimstyle))))
        (if (= "1" (csad:get 'levels))
          (progn
            (csast:insert space "Cao do" (csast:p base (caar points) (cadar points))
              (if preview layer "11-GB-Cao Do") 0.25 (list (cons "%%P0.000" (csad:leveltext bottom))))
            (csast:insert space "Cao do" (csast:p base (car toppt) (cadr toppt))
              (if preview layer "11-GB-Cao Do") 0.25 (list (cons "%%P0.000" (csad:leveltext top))))))
        ;; Replace only previously tagged previews after new geometry succeeds.
        (foreach e old (if (not (entdel e)) (progn (princ "\nCannot delete old preview.") (exit))))
        (vla-Regen doc 0) (vla-EndUndoMark doc) (setq started nil)
        (csad:put 'status (if preview "Section preview updated. Final geometry retained."
                           "Section drawn on CSA layers. Preview removed."))
        (princ (strcat "\n" (csad:get 'status))))))
  (princ))

(defun c:CSA_STAIR_DRAWING (/ action path entry)
  (if (not (boundp '*csad-state*))
    (setq *csad-state* '((title . "ST-01") (section . "1-1") (dimstyle . "GB 25")
      (bottom . "0.000") (top . "0.000") (dims . "1") (levels . "1") (symbol . "1")
      (status . "Load current Excel coordinates to begin."))))
  ;; Migrate cached state from earlier APPLOAD versions without fabricating
  ;; missing detail metadata. Reload Excel once to populate that metadata.
  (foreach entry '((details . "1") (titleheight . "200") (dimgap . "400"))
    (if (not (assoc (car entry) *csad-state*)) (csad:put (car entry) (cdr entry))))
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

(princ "\nCSA Stair concrete-details v2 loaded. Run CSA_STAIR_DRAWING; reload Excel once.")
(princ)
