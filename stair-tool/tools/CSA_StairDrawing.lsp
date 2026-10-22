;;; Generated standalone CSA Stair Drawing; do not edit this bundle.
;;; Source: standards helpers + concrete/rebar planners + ui/CSA_StairDrawing.core.lsp
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

(defun csast:scale-ratio (requested actual)
  (if (or (<= requested 0.0) (<= actual 0.0))
    (progn (princ "\nInvalid block reference scale.") (exit)))
  (/ requested actual))

(defun csast:normalize-scale (o point requested / actual ratio)
  ;; InsertBlock may compensate for block units. Match the reference scale
  ;; accepted in Properties, not the method argument before unit conversion.
  ;; ScaleEntity transforms attributes together with the block geometry.
  (setq actual (vla-get-XScaleFactor o) ratio (csast:scale-ratio requested actual))
  (if (> (abs (- ratio 1.0)) 0.000000001)
    (vla-ScaleEntity o (vlax-3d-point point) ratio))
  (if (or (> (abs (- (vla-get-XScaleFactor o) requested)) 0.00000001)
          (> (abs (- (vla-get-YScaleFactor o) requested)) 0.00000001)
          (> (abs (- (vla-get-ZScaleFactor o) requested)) 0.00000001))
    (progn (princ "\nCannot normalize the block reference scales.") (exit)))
  (vla-Update o))

(defun csast:insert (space name point layer scale values / o attrs att entry found)
  (setq o (csast:track (vla-InsertBlock space (vlax-3d-point point) name scale scale scale 0.0)))
  (vla-put-Layer o layer)
  (csast:normalize-scale o point scale)
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
      (csast:insert space "Daucat" (csast:p base 4000 0) "12-GB-Ky Hieu" 0.01
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
        "; block scales fixed: Cao do=0.25, Daucat=0.01, mark=0.35, note=1.0"
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

;;; Pure geometry planner for the existing 24-row Cau Thang Tools contract.
;;; Raw (not deduplicated) points are indexed by their original STT.
;;; Metadata order: H19 Z19 BA19 D31 D33 BU21 BU22 AO27.
;;; Dimensions are measured geometry, never text overrides.

(defun csad:project (p a b / dx dy denominator factor)
  (setq dx (- (car b) (car a)) dy (- (cadr b) (cadr a))
        denominator (+ (* dx dx) (* dy dy)))
  (if (> denominator 0.000000001)
    (progn
      (setq factor (/ (+ (* (- (car p) (car a)) dx) (* (- (cadr p) (cadr a)) dy)) denominator))
      (list (+ (car a) (* factor dx)) (+ (cadr a) (* factor dy))))))

(defun csad:mid (a b)
  (list (/ (+ (car a) (car b)) 2.0) (/ (+ (cadr a) (cadr b)) 2.0)))

(defun csad:parallel (a b c d / denominator cross)
  (setq denominator (* (distance a b) (distance c d))
        cross (- (* (- (car b) (car a)) (- (cadr d) (cadr c)))
                 (* (- (cadr b) (cadr a)) (- (car d) (car c)))))
  (and (> denominator 0.000000001) (< (/ (abs cross) denominator) 0.000001)))

(defun csad:detail-error (raw metadata / issue value checks pair p q)
  (if (or (/= (length raw) 24) (/= (length metadata) 8))
    (setq issue "Reload Excel: concrete details require the 24-row coordinate contract and 8 parameters."))
  (if (not issue)
    (progn
      (foreach value metadata
        (if (or (not (numberp value)) (and (numberp value) (< value 0.0)))
          (setq issue "Invalid concrete parameter in H19/Z19/BA19/D31/D33/BU21/BU22/AO27.")))
      (if (not issue)
        (progn
          (setq p (csad:mid (nth 2 raw) (nth 3 raw))
                q (csad:project p (nth 13 raw) (nth 14 raw)))
          (if (or (null q) (<= (nth 7 metadata) 0.0)
                  (not (csad:parallel (nth 2 raw) (nth 3 raw) (nth 13 raw) (nth 14 raw))))
            (setq issue "Inclined slab thickness/underside geometry is invalid.")
            (progn
              (setq checks (list
                (list (- (car (nth 1 raw)) (caar raw)) (nth 0 metadata))
                (list (- (car (nth 3 raw)) (car (nth 1 raw))) (nth 1 metadata))
                (list (- (car (nth 5 raw)) (car (nth 3 raw))) (nth 2 metadata))
                (list (- (cadar raw) (cadr (nth 20 raw))) (nth 3 metadata))
                (list (- (cadr (nth 20 raw)) (cadr (nth 22 raw))) (nth 4 metadata))
                (list (- (cadr (nth 4 raw)) (cadr (nth 8 raw))) (nth 5 metadata))
                (list (- (cadr (nth 8 raw)) (cadr (nth 6 raw))) (nth 6 metadata))
                (list (distance p q) (nth 7 metadata))))
              (foreach pair checks
                (if (> (abs (- (car pair) (cadr pair))) 0.5)
                  (setq issue "Concrete parameters do not match coordinates. Recalculate Excel and reload; no dimensions were guessed.")))))))))
  issue)

(defun csad:dim-measure (spec / a b kind)
  (setq kind (nth 1 spec) a (nth 2 spec) b (nth 3 spec))
  (cond ((= kind "H") (abs (- (car b) (car a))))
        ((= kind "V") (abs (- (cadr b) (cadr a))))
        (T (distance a b))))

(defun csad:addspec (name kind a b location specs / item)
  (setq item (list name kind a b location))
  (if (> (csad:dim-measure item) 0.000001) (cons item specs) specs))

(defun csad:detail-specs (raw gap / specs p1 p2 p3 p4 p5 p6 p7 p8 p9
                                p11 p12 p14 p15 p18 p19 p21 p22 p23
                                minx maxx miny maxy uppery p q mid length dx dy)
  (setq p1 (nth 0 raw) p2 (nth 1 raw) p3 (nth 2 raw) p4 (nth 3 raw)
        p5 (nth 4 raw) p6 (nth 5 raw) p7 (nth 6 raw) p8 (nth 7 raw) p9 (nth 8 raw)
        p11 (nth 10 raw) p12 (nth 11 raw) p14 (nth 13 raw) p15 (nth 14 raw)
        p18 (nth 17 raw) p19 (nth 18 raw) p21 (nth 20 raw) p22 (nth 21 raw) p23 (nth 22 raw)
        minx (apply 'min (mapcar 'car raw)) maxx (apply 'max (mapcar 'car raw))
        miny (apply 'min (mapcar 'cadr raw)) maxy (apply 'max (mapcar 'cadr raw)))
  ;; Top horizontal chain: lower landing / flight projection / upper landing.
  (setq specs (csad:addspec "lower_landing" "H" p1 p2 (list minx (+ maxy gap)) specs))
  (setq specs (csad:addspec "flight_run" "H" p2 p4 (list minx (+ maxy gap)) specs))
  (setq specs (csad:addspec "upper_landing" "H" p4 p6 (list minx (+ maxy gap)) specs))
  ;; Floor rise is separate from the total outline height including downstands.
  (setq specs (csad:addspec "floor_rise" "V" p1 p5 (list (- minx (* 3.0 gap)) maxy) specs))
  ;; Lower slab and downstand below slab; total beam depth is suppressed.
  (setq specs (csad:addspec "lower_slab" "V" p21 p1 (list (- minx gap) miny) specs))
  (setq specs (csad:addspec "lower_downstand" "V" p23 p21 (list (- minx gap) miny) specs))
  (setq specs (csad:addspec "lower_first_beam_width" "H" p23 p22 (list minx (- miny gap)) specs))
  (setq specs (csad:addspec "lower_last_beam_width" "H" p19 p18 (list minx (- miny gap)) specs))
  ;; Upper slab/downstand; dimensions are vertical projections, not diagonals.
  (setq specs (csad:addspec "upper_slab" "V" p9 p5 (list (+ maxx gap) maxy) specs))
  (setq specs (csad:addspec "upper_downstand" "V" p7 p9 (list (+ maxx gap) maxy) specs))
  (setq uppery (- (min (cadr p7) (cadr p12)) gap))
  (setq specs (csad:addspec "upper_first_beam_width" "H" p12 p11 (list maxx uppery) specs))
  (setq specs (csad:addspec "upper_last_beam_width" "H" p8 p7 (list maxx uppery) specs))
  (setq specs (csad:addspec "lower_step_rise" "V" p2 p3 (list (- (car p2) gap) (cadr p3)) specs))
  (setq specs (csad:addspec "upper_step_rise" "V" p4 p5 (list (- (car p4) gap) (cadr p5)) specs))
  ;; Perpendicular thickness: project the upper midspan onto the true soffit.
  (setq p (csad:mid p3 p4) q (csad:project p p14 p15)
        mid (csad:mid p q) length (distance p3 p4)
        dx (/ (- (car p4) (car p3)) length) dy (/ (- (cadr p4) (cadr p3)) length))
  (setq specs (csad:addspec "inclined_slab_normal" "A" q p
    (list (- (car mid) (* dx gap)) (- (cadr mid) (* dy gap))) specs))
  (reverse specs))

;;; Fixed extension lines: DIMFXLON=1 (290), DIMFXL (49), per-entity overrides.
;;; DIMFXL is scaled by DIMSCALE, so store 150 / effective scale for 150 model mm.
(defun csad:fixed-dstyle (app model-length dimscale / tail before body after depth found item filtered)
  (setq tail (cdr app))
  (while (and tail (not found))
    (if (and (equal (car tail) (cons 1000 "DSTYLE")) (equal (cadr tail) (cons 1002 "{")))
      (progn
        (setq found T tail (cddr tail) depth 1)
        (while (and tail (> depth 0))
          (setq item (car tail) tail (cdr tail))
          (cond ((equal item (cons 1002 "{")) (setq depth (1+ depth)))
                ((equal item (cons 1002 "}")) (setq depth (1- depth))))
          (if (> depth 0) (setq body (append body (list item)))))
        (setq after tail))
      (setq before (append before (list (car tail))) tail (cdr tail))))
  ;; Replace only these two variable/value pairs; preserve every other override.
  (while body
    (if (and (= (caar body) 1070) (cdr body))
      (progn
        ;; Consume each complete variable/value pair. An integer VALUE of 49
        ;; (e.g. a color) must not be mistaken for the DIMFXL variable code.
        (if (not (member (cdar body) '(49 290)))
          (setq filtered (append filtered (list (car body) (cadr body)))))
        (setq body (cddr body)))
      (setq filtered (append filtered (list (car body))) body (cdr body))))
  (append (list "ACAD") before
    (list (cons 1000 "DSTYLE") (cons 1002 "{")) filtered
    (list (cons 1070 49) (cons 1040 (/ model-length dimscale))
          (cons 1070 290) (cons 1070 1) (cons 1002 "}")) after))

(defun csad:fixed-extension (object model-length / entity data dimscale result group apps app found)
  (setq csad-stage "Dimension: fix extension length to 150 model mm"
        entity (vlax-vla-object->ename object) data (entget entity '("*"))
        dimscale (vla-get-ScaleFactor object))
  (if (<= dimscale 0.0) (setq dimscale (/ 1.0 (getvar "CANNOSCALEVALUE"))))
  (foreach group data
    (if (= (car group) -3)
      (progn
        (setq apps nil)
        (foreach app (cdr group)
          (if (= (car app) "ACAD")
            (setq app (csad:fixed-dstyle app model-length dimscale) found T))
          (setq apps (append apps (list app))))
        (setq group (cons -3 apps))))
    (setq result (append result (list group))))
  (if (not found)
    (setq result (append result (list (list -3 (csad:fixed-dstyle (list "ACAD") model-length dimscale))))))
  (if (not (entmod result)) (progn (princ "\nCannot set fixed extension length on dimension.") (exit)))
  (entupd entity)
  object)

(defun csad:draw-spec (space base spec layer style / a b location kind obj)
  (setq a (nth 2 spec) b (nth 3 spec) location (nth 4 spec) kind (nth 1 spec)
        a (csast:p base (car a) (cadr a)) b (csast:p base (car b) (cadr b))
        location (csast:p base (car location) (cadr location)))
  (if (= kind "A")
    (setq obj (csast:track (vla-AddDimAligned space (vlax-3d-point a)
      (vlax-3d-point b) (vlax-3d-point location))))
    (setq obj (csast:track (vla-AddDimRotated space (vlax-3d-point a)
      (vlax-3d-point b) (vlax-3d-point location) (if (= kind "H") 0.0 (/ pi 2.0))))))
  (vla-put-Layer obj layer) (vla-put-StyleName obj style)
  (csad:fixed-extension obj 150.0)
  (vla-Update obj)
  obj)

(defun csad:center (object target / low high center)
  (vla-Update object)
  (vla-GetBoundingBox object 'low 'high)
  (setq low (vlax-safearray->list low) high (vlax-safearray->list high)
        center (list (/ (+ (car low) (car high)) 2.0)
                     (/ (+ (cadr low) (cadr high)) 2.0)
                     (/ (+ (caddr low) (caddr high)) 2.0)))
  (vla-Move object (vlax-3d-point center) (vlax-3d-point target)))

(defun csad:width (object / low high)
  (vla-GetBoundingBox object 'low 'high)
  (- (car (vlax-safearray->list high)) (car (vlax-safearray->list low))))

(defun csad:caption (space base minx maxx miny titleheight gap preview / x y main prefix symbol pw sw total)
  (setq x (/ (+ minx maxx) 2.0) y (- miny (max (* 3.0 gap) (* 4.0 titleheight)))
        main (csast:text space (csad:get 'title) (csast:p base x y) titleheight
               (if preview "CSA-PREVIEW" "10-GB-Text") "01-GB-Arial"))
  (csad:center main (csast:p base x y))
  (if (= "1" (csad:get 'symbol))
    (progn
      (setq y (- y (* 1.6 titleheight))
            prefix (csast:text space "MAT CAT" (csast:p base x y) (* 0.7 titleheight)
                     (if preview "CSA-PREVIEW" "10-GB-Text") "01-GB-Arial")
            symbol (csast:insert space "Daucat" (csast:p base x y)
                     (if preview "CSA-PREVIEW" "12-GB-Ky Hieu") 0.01
                     (list (cons "A" (csad:get 'section))))
            pw (csad:width prefix) sw (csad:width symbol)
            total (+ pw sw (* 0.5 titleheight)))
      (csad:center prefix (csast:p base (+ (- x (/ total 2.0)) (/ pw 2.0)) y))
      (csad:center symbol (csast:p base (- (+ x (/ total 2.0)) (/ sw 2.0)) y)))))

;;; Step data: U28 (lower count), AI23 (flight count), AV21 (riser),
;;; Z23/Z24 (upper/lower landing bars), Z25/Z26 (upper/lower landing dots).
(defun csad:steps-error (raw options / issue low flight riser)
  (if (or (/= (length raw) 24) (/= (length options) 7))
    (setq issue "Reload Excel for U28/AI23/AV21 step parameters.")
    (progn
      (setq low (nth 0 options) flight (nth 1 options) riser (nth 2 options))
      (if (not (and (numberp low) (numberp flight) (numberp riser)
                    (>= low 0) (> flight 0) (> riser 0)
                    (= low (fix low)) (= flight (fix flight))))
        (setq issue "Step counts must be integers (U28 >= 0, AI23 > 0) and AV21 must be positive.")
        (if (or (> (abs (- (* (+ low flight) riser) (- (cadr (nth 4 raw)) (cadar raw)))) 0.5)
                (> (abs (- (* low riser) (- (cadr (nth 2 raw)) (cadr (nth 1 raw))))) 0.5)
                (> (abs (- riser (- (cadr (nth 4 raw)) (cadr (nth 3 raw))))) 0.5))
          (setq issue "Step counts/riser do not match the concrete. Recalculate Excel and reload.")))))
  issue)

(defun csad:step-labels (raw options gap / a b span dx dy mid result)
  (setq a (nth 2 raw) b (nth 3 raw) span (distance a b)
        dx (/ (- (car b) (car a)) span) dy (/ (- (cadr b) (cadr a)) span)
        mid (csad:mid a b)
        result (list (list (strcat (itoa (fix (nth 1 options))) " BAC")
          (list (- (car mid) (* dy gap)) (+ (cadr mid) (* dx gap))))))
  (if (> (nth 0 options) 0)
    (setq result (append result (list (list (strcat (itoa (fix (nth 0 options))) " BAC")
      (list (- (car a) (* 1.5 gap)) (+ (cadr a) gap)))))))
  result)

(defun csad:draw-steps (space base raw options gap height preview / item object)
  (foreach item (csad:step-labels raw options gap)
    (setq object (csast:text space (car item)
      (csast:p base (car (cadr item)) (cadr (cadr item))) (* 1.5 height)
      (if preview "CSA-PREVIEW" "10-GB-Text") "01-GB-Arial"))
    (csad:center object (csast:p base (car (cadr item)) (cadr (cadr item))))))

;;; Rebar detailing draft from Excel BJ28:BJ41 and Z23:Z26.
;;; Main legs into landings and landing extensions into the slope use BJ38*d.
;;; Existing concrete steps are respected; bend radii and fabrication are pending.
;;; Landing bars run in the section plane, as confirmed by the user.

(defun csar:bar (value / s index diameter spacing)
  (if (= (type value) 'STR)
    (progn
      (setq s (strcase (vl-string-trim " " value)))
      (while (vl-string-search " " s) (setq s (vl-string-subst "" " " s)))
      (if (= (substr s 1 3) "%%C") (setq s (substr s 4)))
      (if (member (substr s 1 1) '("D" "R" "T")) (setq s (substr s 2)))
      (setq index (vl-string-search "A" s))
      (if (null index) (setq index (vl-string-search "@" s)))
      (if (and index (> index 0))
        (progn
          (setq diameter (distof (substr s 1 index) 2)
                spacing (distof (substr s (+ index 2)) 2))
          (if (and diameter spacing (> diameter 0.0) (> spacing 0.0))
            (list diameter spacing (strcat (substr s 1 index) "a" (substr s (+ index 2))))))))))

(defun csar:atx (a b x / dx)
  (setq dx (- (car b) (car a)))
  (if (> (abs dx) 0.000001)
    (list x (+ (cadr a) (* (- x (car a)) (/ (- (cadr b) (cadr a)) dx))))))

(defun csar:offset (a b offsetvalue / segmentlength dx dy)
  ;; Positive = left normal; points are oriented uphill.
  (setq segmentlength (distance a b) dx (/ (- (car b) (car a)) segmentlength)
        dy (/ (- (cadr b) (cadr a)) segmentlength))
  (list (list (- (car a) (* dy offsetvalue)) (+ (cadr a) (* dx offsetvalue)))
        (list (- (car b) (* dy offsetvalue)) (+ (cadr b) (* dx offsetvalue)))))

(defun csar:mainpath (raw cover diameter anchor-d top / radius leg line leftx rightx lowy highy a b)
  (setq radius cover leg (* diameter anchor-d))
  (if top
    (setq line (csar:offset (nth 2 raw) (nth 3 raw) (- 0.0 radius))
          leftx (+ (car (nth 1 raw)) radius)
          rightx (+ (car (nth 4 raw)) radius)
          lowy (- (cadar raw) radius) highy (- (cadr (nth 4 raw)) radius))
    (setq line (csar:offset (nth 14 raw) (nth 13 raw) radius)
          leftx (- (car (nth 15 raw)) radius)
          rightx (- (car (nth 10 raw)) radius)
          lowy (+ (cadr (nth 20 raw)) radius) highy (+ (cadr (nth 8 raw)) radius)))
  (setq a (csar:atx (car line) (cadr line) leftx)
        b (csar:atx (car line) (cadr line) rightx))
  (list (list (- leftx leg) lowy) (list leftx lowy) a b
        (list rightx highy) (list (+ rightx leg) highy)))

(defun csar:landingline (raw cover diameter upper top / radius leftx rightx y)
  (setq radius cover)
  (if upper
    (setq leftx (+ (car (nth 4 raw)) radius) rightx (- (car (nth 5 raw)) radius)
          y (if top (- (cadr (nth 4 raw)) radius) (+ (cadr (nth 8 raw)) radius)))
    (setq leftx (+ (caar raw) radius)
          rightx (- (car (nth (if top 1 15) raw)) radius)
          y (if top (- (cadar raw) radius) (+ (cadr (nth 20 raw)) radius))))
  (list (list leftx y) (list rightx y)))

(defun csar:advance (a b amount / span)
  (setq span (distance a b))
  (list (+ (car a) (* amount (/ (- (car b) (car a)) span)))
        (+ (cadr a) (* amount (/ (- (cadr b) (cadr a)) span)))))

(defun csar:landingpath (raw cover diameter anchor-d upper top / path edge bend knee endpoint)
  ;; Follow the same layer through the concrete step, then anchor BJ38*d
  ;; along the incline. The vertical transition is not counted as this length.
  (setq path (csar:mainpath raw cover diameter anchor-d top)
        edge (csar:landingline raw cover diameter upper top))
  (if upper
    (setq edge (cadr edge) bend (nth 4 path) knee (nth 3 path)
          endpoint (csar:advance knee (nth 2 path) (* diameter anchor-d)))
    (setq edge (car edge) bend (nth 1 path) knee (nth 2 path)
          endpoint (csar:advance knee (nth 3 path) (* diameter anchor-d))))
  (list edge bend knee endpoint))

(defun csar:flag (value / s)
  (cond ((numberp value) (cond ((= value 1) 1) ((= value 0) 0)))
        ((= (type value) 'STR)
          (setq s (strcase (vl-string-trim " " value)))
          (cond ((member s '("YES" "Y" "TRUE" "1")) 1)
                ((member s '("NO" "N" "FALSE" "0")) 0)))))

(defun csar:stations (a b spacing / span count margin index result factor)
  ;; Center the exact-spacing grid, leaving equal end margins.
  (setq span (distance a b) count (fix (/ span spacing))
        margin (/ (- span (* count spacing)) 2.0) index 0)
  (while (<= index count)
    (setq factor (/ (+ margin (* index spacing)) span)
          result (cons (list (+ (car a) (* factor (- (car b) (car a))))
                             (+ (cadr a) (* factor (- (cadr b) (cadr a))))) result)
          index (1+ index)))
  (reverse result))

(defun csar:distribution-line (raw cover main-d diameter top / line radius dx dy span)
  ;; User convention: longitudinal axis at cover, dot axis another d_transverse/2 inside.
  (setq radius (+ cover (/ diameter 2.0)))
  (if top
    (setq line (csar:offset (nth 2 raw) (nth 3 raw) (- 0.0 radius)))
    (setq line (csar:offset (nth 14 raw) (nth 13 raw) radius)))
  (setq span (distance (car line) (cadr line))
        dx (/ (- (caadr line) (caar line)) span)
        dy (/ (- (cadadr line) (cadar line)) span))
  (list (list (+ (caar line) (* radius dx)) (+ (cadar line) (* radius dy)))
        (list (- (caadr line) (* radius dx)) (- (cadadr line) (* radius dy)))))

(defun csar:landing-distribution-line (raw cover main-d diameter upper top)
  (csar:landingline raw (+ cover (/ diameter 2.0)) diameter upper top))

(defun csar:point-clearance (point polygon / edges result)
  (setq edges (append polygon (list (car polygon))) result 1.0e20)
  (if (not (csar:inside point polygon)) 0.0
    (progn
      (while (cdr edges)
        (setq result (min result (csar:point-segment-distance point (car edges) (cadr edges)))
              edges (cdr edges)))
      result)))

(defun csar:distribution-specs (raw data options / specs top side main bar line)
  ;; Each item: region, top flag, sampling line; same BJ36 diameter/spacing.
  (setq bar (csar:bar (nth 8 data)))
  (foreach top (if (= (csar:layers data) 2) (list nil T) (list nil))
    (setq main (csar:bar (nth (if top 7 6) data))
          line (csar:distribution-line raw (car data) (car main) (car bar) top)
          specs (cons (list "FLIGHT" top line) specs))
    (foreach side (list nil T)
      (if (= 1 (csar:flag (nth (if side 5 6) options)))
        (progn
          (setq main (csar:bar (nth (if side 5 4) data))
                line (csar:landing-distribution-line raw (car data) (car main) (car bar) side top)
                specs (cons (list (if side "UPPER" "LOWER") top line) specs))))))
  (reverse specs))

(defun csar:point-segment-distance (p a b / q factor dx dy denominator)
  (setq dx (- (car b) (car a)) dy (- (cadr b) (cadr a))
        denominator (+ (* dx dx) (* dy dy)))
  (if (< denominator 0.000000001) (distance p a)
    (progn
      (setq factor (/ (+ (* (- (car p) (car a)) dx) (* (- (cadr p) (cadr a)) dy)) denominator)
            factor (max 0.0 (min 1.0 factor))
            q (list (+ (car a) (* factor dx)) (+ (cadr a) (* factor dy))))
      (distance p q))))

(defun csar:segment-distance (a b c d)
  (if (inters a b c d T) 0.0
    (min (csar:point-segment-distance a c d) (csar:point-segment-distance b c d)
         (csar:point-segment-distance c a b) (csar:point-segment-distance d a b))))

(defun csar:inside (p polygon / edges a b crossing inside)
  (setq edges (append polygon (list (car polygon))))
  (while (cdr edges)
    (setq a (car edges) b (cadr edges))
    (if (not (eq (> (cadr a) (cadr p)) (> (cadr b) (cadr p))))
      (progn
        (setq crossing (+ (car a) (* (- (cadr p) (cadr a))
                           (/ (- (car b) (car a)) (- (cadr b) (cadr a))))))
        (if (< (car p) crossing) (setq inside (not inside)))))
    (setq edges (cdr edges)))
  inside)

(defun csar:path-clearance (path polygon / result lines edges a b)
  (setq result 1.0e20 lines path)
  (while (cdr lines)
    (setq a (car lines) b (cadr lines) edges (append polygon (list (car polygon))))
    (if (not (csar:inside (csad:mid a b) polygon)) (setq result 0.0))
    (while (cdr edges)
      (setq result (min result (csar:segment-distance a b (car edges) (cadr edges)))
            edges (cdr edges)))
    (setq lines (cdr lines)))
  result)

(defun csar:path-distance (first second / result a b)
  (setq result 1.0e20 a first)
  (while (cdr a)
    (setq b second)
    (while (cdr b)
      (setq result (min result (csar:segment-distance (car a) (cadr a) (car b) (cadr b)))
            b (cdr b)))
    (setq a (cdr a)))
  result)

(defun csar:layers (data / mode)
  (setq mode (nth 9 data))
  (if (= (type mode) 'STR)
    (cond ((= (substr (vl-string-trim " " mode) 1 1) "1") 1)
          ((= (substr (vl-string-trim " " mode) 1 1) "2") 2))))

(defun csar:error (raw concrete data options / issue cover bottom top layers value path radius firstmark side bar spec specs line other)
  (setq issue (csad:detail-error raw concrete))
  (if (not issue)
    (cond
      ((/= (length data) 14) (setq issue "Reload Excel for reinforcement parameters BJ28:BJ41."))
      ((/= (length options) 7) (setq issue "Reload Excel for step counts and Z23:Z26 switches."))
      (T
        (setq cover (nth 0 data) layers (csar:layers data) firstmark (nth 11 data))
        (foreach value '(3 4 5 6)
          (if (null (csar:flag (nth value options)))
            (setq issue "Z23:Z26 must be Yes/No (landing bars and transverse dots).")))
        (foreach value (list cover (nth 1 data) (nth 3 data) (nth 10 data) firstmark (nth 12 data))
          (if (or (not (numberp value)) (and (numberp value) (<= value 0.0)))
            (setq issue "Cover, widths, anchor d, first mark and member count must be positive.")))
        (if (and (numberp firstmark) (/= firstmark (fix firstmark)))
          (setq issue "First bar mark must be an integer."))
        (if (not layers) (setq issue "BJ37 must specify 1 or 2 reinforcement layers."))
        (foreach value '(4 5 6 7 8)
          (if (not (csar:bar (nth value data)))
            (setq issue "Use diameter/spacing such as 12a150 in BJ32:BJ36.")))
        (if (not issue)
          (progn
            (setq bottom (csar:bar (nth 6 data)) top (csar:bar (nth 7 data)))
            (foreach value (if (= layers 2) (list nil T) (list nil))
              (setq radius cover
                    path (csar:mainpath raw cover (car (if value top bottom)) (nth 10 data) value))
              (if (< (csar:path-clearance path (csad:cleanpoints raw)) (- radius 0.01))
                (setq issue "Main bar legs do not fit concrete/cover; no anchor was shortened automatically.")))
            (if (and (= layers 2)
                     (< (csar:path-distance
                          (csar:mainpath raw cover (car bottom) (nth 10 data) nil)
                          (csar:mainpath raw cover (car top) (nth 10 data) T))
                        (/ (+ (car bottom) (car top)) 2.0)))
              (setq issue "Top and bottom bars overlap. Check cover, diameters and support dimensions."))
            (foreach side (list nil T)
              (if (= 1 (csar:flag (nth (if side 3 4) options)))
                (progn
                  (setq bar (csar:bar (nth (if side 5 4) data)) radius cover)
                  (foreach value (if (= layers 2) (list nil T) (list nil))
                    (setq path (csar:landingpath raw cover (car bar) (nth 10 data) side value))
                    (if (< (csar:path-clearance path (csad:cleanpoints raw)) (- radius 0.01))
                      (setq issue "Landing bars do not fit concrete/cover. Check BJ32/BJ33 and anchorage.")))
                  (if (and (= layers 2)
                           (< (csar:path-distance
                                (csar:landingpath raw cover (car bar) (nth 10 data) side nil)
                                (csar:landingpath raw cover (car bar) (nth 10 data) side T)) (car bar)))
                    (setq issue "Landing reinforcement layers overlap; check cover and diameter.")))))
            (if (not issue)
              (progn
                (setq bar (csar:bar (nth 8 data)) specs (csar:distribution-specs raw data options))
                (foreach spec specs
                  (setq line (nth 2 spec) radius (+ cover (/ (car bar) 2.0)))
                  (if (or (<= (distance (car line) (cadr line)) 0.001)
                          (> (/ (distance (car line) (cadr line)) (cadr bar)) 2000)
                          (< (csar:path-clearance line (csad:cleanpoints raw)) (- radius 0.01)))
                    (setq issue "Transverse bars do not fit cover, or exceed 2000 dots per region/layer. Check BJ36 and slab geometry."))
                  (foreach other specs
                    (if (and (= (car spec) (car other)) (not (eq (cadr spec) (cadr other)))
                             (< (csar:path-distance line (nth 2 other)) (car bar)))
                      (setq issue "Top/bottom transverse bars overlap; check cover, diameters and slab thickness.")))))))))))
  issue)

(defun csar:polyline (space base points layer / coords p array object)
  (setq csad-stage "Rebar: create polyline")
  (foreach p points
    (setq coords (append coords (list (+ (car base) (car p)) (+ (cadr base) (cadr p))))))
  (setq array (vlax-make-safearray vlax-vbDouble (cons 0 (1- (length coords)))))
  (vlax-safearray-fill array coords)
  (setq object (csast:track (vla-AddLightWeightPolyline space array)))
  (vla-put-Layer object layer) (vla-put-Elevation object (caddr base))
  (vla-put-Closed object :vlax-false)
  object)

(defun csar:dot (space base point diameter layer / object)
  ;; Two semicircular wide arcs make a filled disk, with actual outside diameter d.
  ;; No hatch, block, POINT display mode, or global variable is required.
  (setq object (csar:polyline space base
    (list (list (- (car point) (/ diameter 4.0)) (cadr point))
          (list (+ (car point) (/ diameter 4.0)) (cadr point))) layer))
  (setq csad-stage "Transverse dot: set bulges and width")
  (vla-put-Closed object :vlax-true)
  (vla-SetBulge object 0 1.0) (vla-SetBulge object 1 1.0)
  (vla-put-ConstantWidth object (/ diameter 2.0))
  object)

(defun csar:leader (space base points layer dotted size style annotation / coords point array object)
  (foreach point points
    (setq coords (append coords (csast:p base (car point) (cadr point)))))
  (setq array (vlax-make-safearray vlax-vbDouble (cons 0 (1- (length coords)))))
  (vlax-safearray-fill array coords)
  ;; Annotation must be an existing CSA BlockReference, not a missing nil argument.
  ;; AcLeaderType: 0 = acLineWithArrow, 1 = acSplineWithArrow (curved).
  (setq csad-stage "Leader: AddLeader straight segments with CSA annotation")
  (setq object (csast:track (vla-AddLeader space array annotation 0)))
  (setq csad-stage "Leader: set layer and DimStyle")
  (vla-put-Layer object layer) (vla-put-StyleName object style)
  (setq csad-stage "Leader: set straight Type / ScaleFactor")
  (vla-put-Type object 0)
  (vla-put-ScaleFactor object 1.0)
  ;; AcDimArrowheadType: 12 = acArrowDotBlank, 4 = acArrowArchTick.
  (setq csad-stage "Leader: set ArrowheadType and model-space size")
  (vla-put-ArrowheadType object (if dotted 12 4))
  (vla-put-ArrowheadSize object size)
  ;; Associating an annotation may reposition vertices/add a landing. Reapply
  ;; the exact three vertices after the style and annotation have been assigned.
  (setq csad-stage "Leader: restore diagonal and horizontal coordinates")
  (vla-put-Coordinates object array)
  (vla-Update object)
  object)

(defun csar:note-route (target low high textlow texthigh height / y near far margin)
  ;; Horizontal leg under the diameter/spacing attribute, not through its center.
  ;; It runs from the side closest to the target to the far side of the text.
  (setq margin (max 10.0 (* 0.2 height)) y (- (cadr textlow) margin))
  (if (< (car target) (/ (+ (car low) (car high)) 2.0))
    (setq near (- (car low) (* 2.0 height)) far (car texthigh))
    (setq near (+ (car high) (* 2.0 height)) far (car textlow)))
  (list target (list near y) (list far y)))

(defun csar:note (space base target point bar mark dotted preview height / layer note low high attrs att textlow texthigh route)
  (setq csad-stage (strcat "Rebar mark " (itoa mark) ": insert CSA note block"))
  (setq layer (if preview "CSA-PREVIEW" "20-GB-GC")
        note (csast:insert space "CSA_Sohieu-KCthep" (csast:p base (car point) (cadr point))
          layer 1.0 (list (cons "SH" (itoa mark)) (cons "DK-KC" (strcat "%%C" (nth 2 bar))))))
  (setq csad-stage (strcat "Rebar mark " (itoa mark) ": center note / GetBoundingBox"))
  (csad:center note (csast:p base (car point) (cadr point)))
  (vla-GetBoundingBox note 'low 'high)
  (setq low (vlax-safearray->list low) high (vlax-safearray->list high)
        attrs (vlax-invoke note 'GetAttributes))
  (foreach att attrs
    (if (= (strcase (vla-get-TagString att)) "DK-KC")
      (progn
        (vla-GetBoundingBox att 'textlow 'texthigh)
        (setq textlow (vlax-safearray->list textlow) texthigh (vlax-safearray->list texthigh)))))
  ;; Existing block/tag preflight guarantees DK-KC. All bounds are WCS here.
  (setq route (csar:note-route (csast:p base (car target) (cadr target)) low high textlow texthigh height)
        route (mapcar '(lambda (p) (list (- (car p) (car base)) (- (cadr p) (cadr base)))) route))
  (csar:leader space base route layer dotted
    (distof (csad:get (if dotted 'dotsize 'ticksize)) 2) (csad:get 'dimstyle) note)
  note)

(defun csar:render (space base raw data options preview gap height / cover layers top bar path mark a b side
                                                        midpoint normal point minx miny text spec line dots dot)
  (setq cover (nth 0 data) layers (csar:layers data) mark (fix (nth 11 data))
        minx (apply 'min (mapcar 'car raw)) miny (apply 'min (mapcar 'cadr raw)))
  (foreach top (if (= layers 2) (list nil T) (list nil))
    (setq bar (csar:bar (nth (if top 7 6) data))
          path (csar:mainpath raw cover (car bar) (nth 10 data) top)
          a (nth 2 path) b (nth 3 path)
          midpoint (csar:advance a b (* (if top 0.6 0.4) (distance a b)))
          normal (csar:offset a b (if top (* 2.0 gap) (- 0.0 (* 2.0 gap))))
          point (csar:advance (car normal) (cadr normal)
                    (* (if top 0.6 0.4) (distance a b))))
    (csar:polyline space base path (if preview "CSA-PREVIEW" "18-GB-Reinf"))
    (csar:note space base midpoint point bar mark nil preview height)
    (setq mark (1+ mark)))
  (foreach side (list nil T)
    (if (= 1 (csar:flag (nth (if side 3 4) options)))
      (progn
        (setq bar (csar:bar (nth (if side 5 4) data)))
        (foreach top (if (= layers 2) (list nil T) (list nil))
          (setq path (csar:landingpath raw cover (car bar) (nth 10 data) side top)
                midpoint (csad:mid (car path) (cadr path))
                point (list (car midpoint)
                  (+ (if side (cadr (nth 4 raw)) (cadar raw)) (* (if top 2.0 1.0) gap))))
          (csar:polyline space base path (if preview "CSA-PREVIEW" "18-GB-Reinf"))
          (csar:note space base midpoint point bar mark nil preview height)
          (setq mark (1+ mark))))))
  ;; One mark per distribution region/layer, every dot has the actual BJ36 diameter.
  (setq bar (csar:bar (nth 8 data)))
  (foreach spec (csar:distribution-specs raw data options)
    (setq line (nth 2 spec) top (nth 1 spec)
          dots (csar:stations (car line) (cadr line) (cadr bar))
          midpoint (nth (fix (/ (length dots) 2.0)) dots))
    (foreach dot dots (csar:dot space base dot (car bar) (if preview "CSA-PREVIEW" "18-GB-Reinf")))
    (if (= (car spec) "FLIGHT")
      (progn
        (setq normal (csar:offset (car line) (cadr line) (if top (* 3.0 gap) (- 0.0 (* 3.0 gap))))
              point (csad:mid (car normal) (cadr normal))))
      (setq point (list (car midpoint)
        (- (if (= (car spec) "UPPER") (cadr (nth 8 raw)) (cadr (nth 20 raw)))
           (* (if top 1.0 2.0) gap)))))
    (csar:note space base midpoint point bar mark T preview height)
    (setq mark (1+ mark)))
  (setq text (strcat "REBAR DRAFT / COVER=" (rtos cover 2 0)
    " / MAIN LEGS AND LANDING SLOPE EXTENSIONS=" (rtos (nth 10 data) 2 0) "d"))
  (csast:text space text (csast:p base minx (- miny (* 5.0 gap))) height
    (if preview "CSA-PREVIEW" "20-GB-GC") "01-GB-Arial")
  (csast:text space "CHECK PROJECTED LAPS / BEND RADII AND FABRICATION SCHEDULE NOT GENERATED"
    (csast:p base minx (- miny (* 5.0 gap) (* 2.0 height))) height
    (if preview "CSA-PREVIEW" "20-GB-GC") "01-GB-Arial"))

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
                           points rawpoints metadata rebar-data section-options rawcount rise bottom title firstlevel high found)
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
  (setq rebar-data nil row 28)
  (while (<= row 41)
    (setq rebar-data (append rebar-data (list (csad:cell cells row 62))) row (1+ row)))
  (setq section-options (list (csad:cell cells 28 21) (csad:cell cells 23 35)
    (csad:cell cells 21 48) (csad:cell cells 23 26) (csad:cell cells 24 26)
    (csad:cell cells 25 26) (csad:cell cells 26 26)))
  (csad:put 'rebar-data rebar-data)
  (csad:put 'section-options section-options)
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
  (foreach key '("title" "section" "bottom" "top" "dims" "details" "levels" "symbol" "steps" "rebar" "titleheight" "dimgap" "dotsize" "ticksize")
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
          ": text { label = \"Daucat : 0.01\"; }"
          ": text { label = \"So hieu thep : 0.35\"; }"
          ": text { label = \"CSA_Sohieu-KCthep : 1.0\"; }"
          ": text { label = \"Preview in the AutoCAD viewport\"; } } }"
          ": row { : edit_box { key = \"titleheight\"; label = \"Title height (mm)\"; edit_width = 12; }"
          ": edit_box { key = \"dimgap\"; label = \"Dimension spacing (mm)\"; edit_width = 12; } }"
          ": row { : edit_box { key = \"dotsize\"; label = \"Dot blank size (mm)\"; edit_width = 12; }"
          ": edit_box { key = \"ticksize\"; label = \"Tick size (mm)\"; edit_width = 12; } }"
          ": boxed_row { label = \"Section options\";"
          ": toggle { key = \"dims\"; label = \"Overall width\"; }"
          ": toggle { key = \"details\"; label = \"Concrete details\"; }"
          ": toggle { key = \"levels\"; label = \"Elevations\"; }"
          ": toggle { key = \"symbol\"; label = \"Section symbol\"; } }"
          ": toggle { key = \"steps\"; label = \"Step counts from Excel (U28 / AI23)\"; }"
          ": toggle { key = \"rebar\"; label = \"Rebar draft - bent landing anchors and transverse dots\"; }"
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
          (foreach name '("title" "section" "bottom" "top" "dims" "details" "levels" "symbol" "steps" "rebar" "status" "titleheight" "dimgap" "dotsize" "ticksize")
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
                            height titleheight gap specs spec ds p toppt bottom top need name issue entities csad-stage)
  (defun *error* (msg)
    (foreach o csast-created (vl-catch-all-apply 'vla-Delete (list o)))
    (if started (vl-catch-all-apply 'vla-EndUndoMark (list doc)))
    (if msg (princ (strcat "\nSection stopped at [" (if csad-stage csad-stage "unknown") "]: " msg)))
    (alert (strcat "Section operation stopped at: " (if csad-stage csad-stage "unknown")
      "\n" (if msg msg "No error message.") "\nCheck command history (F2)."))
    (princ))
  (setq csad-stage "Section preflight")
  (setq points (csad:get 'points) bottom (distof (csad:get 'bottom) 2)
        top (distof (csad:get 'top) 2) old (csad:owned)
        titleheight (distof (csad:get 'titleheight) 2) gap (distof (csad:get 'dimgap) 2))
  (if (or (null titleheight) (null gap)
          (and titleheight (<= titleheight 0.0)) (and gap (<= gap 0.0)))
    (setq issue "Title height and dimension spacing must be positive numbers."))
  (if (= "1" (csad:get 'rebar))
    (foreach name '(dotsize ticksize)
      (setq spec (distof (csad:get name) 2))
      (if (or (null spec) (and spec (<= spec 0)))
        (setq issue "Dot blank and Tick sizes must be positive model-space millimetres."))))
  (if (= "1" (csad:get 'details))
    (if (setq spec (csad:detail-error (csad:get 'rawpoints) (csad:get 'concrete-parameters)))
      (setq issue spec)))
  (if (= "1" (csad:get 'rebar))
    (if (setq spec (csar:error (csad:get 'rawpoints) (csad:get 'concrete-parameters) (csad:get 'rebar-data) (csad:get 'section-options)))
      (setq issue spec)))
  (if (= "1" (csad:get 'steps))
    (if (setq spec (csad:steps-error (csad:get 'rawpoints) (csad:get 'section-options)))
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
  (if (and (not preview) (= "1" (csad:get 'rebar)))
    (setq need (append need '("18-GB-Reinf" "20-GB-GC"))))
  (foreach name need
    (if (and (not (and preview (= name "CSA-PREVIEW") (not (tblsearch "LAYER" name))))
             (not (csad:layerready name)))
      (setq issue (strcat "Missing, off, frozen or locked layer: " name))))
  (if (not (tblsearch "STYLE" "01-GB-Arial")) (setq issue "Missing text style: 01-GB-Arial"))
  (foreach name (if (= "1" (csad:get 'levels)) '("Cao do") nil)
    (if (not (member "%%P0.000" (csast:tags name))) (setq issue "Missing block/tag: Cao do/%%P0.000")))
  (if (and (= "1" (csad:get 'symbol)) (not (member "A" (csast:tags "Daucat"))))
    (setq issue "Missing block/tag: Daucat/A"))
  (if (and (= "1" (csad:get 'rebar))
           (not (and (member "SH" (csast:tags "CSA_Sohieu-KCthep"))
                     (member "DK-KC" (csast:tags "CSA_Sohieu-KCthep")))))
    (setq issue "Missing block/tags: CSA_Sohieu-KCthep / SH / DK-KC"))
  (foreach e old
    (if (not (csad:layerready (cdr (assoc 8 (entget e)))))
      (setq issue "Old preview layer is off, frozen or locked.")))
  (if issue (alert issue)
    (if (setq base (getpoint (if preview "\nPick section preview origin: " "\nPick final section origin: ")))
      (progn
        (setq csad-stage "Section: get active document and ModelSpace")
        (setq base (trans base 1 0)
              doc (vla-get-ActiveDocument (vlax-get-acad-object)) space (vla-get-ModelSpace doc)
              csast-app (if preview "CSA_STAIR_PREVIEW" "CSA_STAIR_FINAL")
              layer (if preview "CSA-PREVIEW" "21-GB-BD"))
        (setq csad-stage "Section: StartUndoMark / prepare layer")
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
        (setq csad-stage "Concrete: create outline")
        (setq pl (csast:track (vla-AddLightWeightPolyline space array)))
        (vla-put-Layer pl layer) (vla-put-Closed pl :vlax-true) (vla-put-Elevation pl (caddr base))
        (setq csad-stage "Caption: title and Daucat")
        (csad:caption space base minx maxx miny titleheight gap preview)
        (setq csad-stage "Concrete: dimensions")
        (if (= "1" (csad:get 'dims))
          (csad:draw-spec space base
            (list "overall_width" "H" (list minx miny) (list maxx miny)
                  (list (/ (+ minx maxx) 2.0) (- miny (* 2.0 gap))))
            (if preview layer "04-GB-Dim") (csad:get 'dimstyle)))
        (if (= "1" (csad:get 'details))
          (foreach spec (csad:detail-specs (csad:get 'rawpoints) gap)
            (csad:draw-spec space base spec (if preview layer "04-GB-Dim") (csad:get 'dimstyle))))
        (setq csad-stage "Elevations: Cao do blocks")
        (if (= "1" (csad:get 'levels))
          (progn
            (csast:insert space "Cao do" (csast:p base (caar points) (cadar points))
              (if preview layer "11-GB-Cao Do") 0.25 (list (cons "%%P0.000" (csad:leveltext bottom))))
            (csast:insert space "Cao do" (csast:p base (car toppt) (cadr toppt))
              (if preview layer "11-GB-Cao Do") 0.25 (list (cons "%%P0.000" (csad:leveltext top))))))
        (setq csad-stage "Steps: labels and bounding boxes")
        (if (= "1" (csad:get 'steps))
          (csad:draw-steps space base (csad:get 'rawpoints) (csad:get 'section-options) gap height preview))
        (setq csad-stage "Rebar: start drawing")
        (if (= "1" (csad:get 'rebar))
          (csar:render space base (csad:get 'rawpoints) (csad:get 'rebar-data)
            (csad:get 'section-options) preview gap height))
        ;; Replace only previously tagged previews after new geometry succeeds.
        (setq csad-stage "Section: replace old preview / Regen")
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
  (foreach entry '((details . "1") (titleheight . "200") (dimgap . "400") (rebar . "0") (steps . "1") (dotsize . "60") (ticksize . "100"))
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

(princ "\nCSA Stair rebar-detail v4.2 loaded. Run CSA_STAIR_DRAWING; reload Excel once.")
(princ)
