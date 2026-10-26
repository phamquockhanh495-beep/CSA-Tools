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
                                minx maxx miny maxy uppery p q mid flight-span dx dy)
  (setq p1 (nth 0 raw) p2 (nth 1 raw) p3 (nth 2 raw) p4 (nth 3 raw)
        p5 (nth 4 raw) p6 (nth 5 raw) p7 (nth 6 raw) p8 (nth 7 raw) p9 (nth 8 raw)
        p11 (nth 10 raw) p12 (nth 11 raw) p14 (nth 13 raw) p15 (nth 14 raw)
        p18 (nth 17 raw) p19 (nth 18 raw) p21 (nth 20 raw) p22 (nth 21 raw) p23 (nth 22 raw)
        minx (apply 'min (mapcar 'car raw)) maxx (apply 'max (mapcar 'car raw))
        miny (apply 'min (mapcar 'cadr raw)) maxy (apply 'max (mapcar 'cadr raw)))
  ;; Top horizontal chain: lower landing / flight projection / upper landing.
  (setq specs (csad:addspec "lower_landing" "H" p1 p2 (list minx (+ maxy 775.0)) specs))
  (setq specs (csad:addspec "flight_run" "H" p2 p4 (list minx (+ maxy 775.0)) specs))
  (setq specs (csad:addspec "upper_landing" "H" p4 p6 (list minx (+ maxy 775.0)) specs))
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
        mid (csad:mid p q) flight-span (distance p3 p4)
        dx (/ (- (car p4) (car p3)) flight-span) dy (/ (- (cadr p4) (cadr p3)) flight-span))
  (setq specs (csad:addspec "inclined_slab_normal" "A" q p
    (list (- (car mid) (* dx gap)) (- (cadr mid) (* dy gap))) specs))
  (reverse specs))

;;; Use AutoCAD's native override command instead of hand-writing DSTYLE xdata.
;;; Each group contains only newly created dimensions with the same scale.
(defun csad:dimension-scale (object / scale)
  (setq scale (vla-get-ScaleFactor object))
  (if (<= scale 0.0) (setq scale (/ 1.0 (getvar "CANNOSCALEVALUE"))))
  scale)

(defun csad:dimoverride (selection scaled-length / previous-echo result)
  (setq previous-echo (getvar "CMDECHO"))
  (setvar "CMDECHO" 0)
  ;; command-s completes in a temporary command processor; no interactive PAUSE.
  ;; The native command validates and serializes the dimension overrides.
  (setq result (vl-catch-all-apply 'command-s
    (list "_.DIMOVERRIDE" "DIMFXLON" "_ON" "DIMFXL" scaled-length "" selection "")))
  (setvar "CMDECHO" previous-echo)
  (if (vl-catch-all-error-p result)
    (progn
      (princ (strcat "\nDIMOVERRIDE failed: " (vl-catch-all-error-message result)))
      (exit)))
  T)

(defun csad:fixed-extensions (objects model-length / groups group object scale selection)
  (setq csad-stage "Dimensions: native DIMOVERRIDE, fixed extension length 200 model mm")
  (foreach object objects
    (setq scale (csad:dimension-scale object) group (assoc scale groups))
    (if group
      (setq groups (subst (cons scale (cons object (cdr group))) group groups))
      (setq groups (cons (list scale object) groups))))
  (foreach group groups
    (setq selection (ssadd))
    (foreach object (cdr group)
      (ssadd (vlax-vla-object->ename object) selection))
    (csad:dimoverride selection (/ model-length (car group))))
  T)

(defun csad:short-feet (spec limit / a b location axis span normal point foot amount result)
  (setq a (nth 2 spec) b (nth 3 spec) location (nth 4 spec)
        axis (cond ((= (nth 1 spec) "H") '(1.0 0.0))
                   ((= (nth 1 spec) "V") '(0.0 1.0))
                   (T (setq span (distance a b))
                      (list (/ (- (car b) (car a)) span) (/ (- (cadr b) (cadr a)) span))))
        normal (list (- 0.0 (cadr axis)) (car axis)))
  (foreach point (list a b)
    (setq amount (+ (* (- (car location) (car point)) (car normal))
                    (* (- (cadr location) (cadr point)) (cadr normal)))
          foot (list (+ (car point) (* amount (car normal))) (+ (cadr point) (* amount (cadr normal)))))
    (if (> (abs amount) 0.001)
      (setq result (cons (list foot (csar:advance foot point (min limit (abs amount)))) result))))
  (reverse result))

(defun csad:draw-spec (space base spec layer style / a b location kind obj segment)
  (setq a (nth 2 spec) b (nth 3 spec) location (nth 4 spec) kind (nth 1 spec)
        a (csast:p base (car a) (cadr a)) b (csast:p base (car b) (cadr b))
        location (csast:p base (car location) (cadr location)))
  (if (= kind "A")
    (setq obj (csast:track (vla-AddDimAligned space (vlax-3d-point a)
      (vlax-3d-point b) (vlax-3d-point location))))
    (setq obj (csast:track (vla-AddDimRotated space (vlax-3d-point a)
      (vlax-3d-point b) (vlax-3d-point location) (if (= kind "H") 0.0 (/ pi 2.0))))))
  (vla-put-Layer obj layer) (vla-put-StyleName obj style)
  (if (nth 5 spec) (vla-put-TextOverride obj (nth 5 spec)))
  ;; Native measurement points remain untouched; replace only extension strokes.
  (vla-put-ExtLine1Suppress obj :vlax-true)
  (vla-put-ExtLine2Suppress obj :vlax-true)
  (foreach segment (csad:short-feet spec 200.0)
    (csast:line space (csast:p base (caar segment) (cadar segment))
      (csast:p base (caadr segment) (cadadr segment)) layer))
  (setq csad-dimensions (cons obj csad-dimensions))
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
  ;; Counts label the stair; concrete neck heights are independent Excel inputs.
  ;; A zero neck is valid even when U28 remains nonzero. Geometry checks remain
  ;; in detail-error and rebar preflight, not in the count-label validation.
  (if (or (/= (length raw) 24) (/= (length options) 7))
    (setq issue "Reload Excel for U28/AI23/AV21 step parameters.")
    (progn
      (setq low (nth 0 options) flight (nth 1 options) riser (nth 2 options))
      (if (not (and (numberp low) (numberp flight) (numberp riser)
                    (>= low 0) (> flight 0) (> riser 0)
                    (= low (fix low)) (= flight (fix flight))))
        (setq issue "Step counts must be integers (U28 >= 0, AI23 > 0) and AV21 must be positive."))))
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

(defun csad:step-dim-text (raw options / count run)
  (setq count (fix (nth 1 options)) run (- (car (nth 3 raw)) (car (nth 1 raw))))
  ;; <> preserves the dimension's real measured total, not a hard-coded value.
  (strcat (itoa count) " x " (rtos (/ run count) 2 2) " = <>"))

(defun csad:step-spec (raw options gap / spec result)
  (foreach spec (csad:detail-specs raw gap)
    (if (= (car spec) "flight_run")
      (setq result (append spec (list (csad:step-dim-text raw options))))))
  result)

(defun csad:draw-steps (space base raw options gap height preview)
  (csad:draw-spec space base (csad:step-spec raw options gap)
    (if preview "CSA-PREVIEW" "04-GB-Dim") (csad:get 'dimstyle)))

(defun csad:level-guides (raw / left right)
  (setq left (- (caar raw) 500.0) right (+ (car (nth 5 raw)) 500.0))
  (list (list (list left (cadar raw)) (list right (cadar raw)))
        (list (list left (cadr (nth 4 raw))) (list right (cadr (nth 4 raw))))))

(defun csad:draw-levels (space base raw bottom top preview / guides guide value)
  (setq guides (csad:level-guides raw))
  (foreach value (list bottom top)
    (setq guide (car guides) guides (cdr guides))
    (csast:line space (csast:p base (caar guide) (cadar guide))
      (csast:p base (caadr guide) (cadadr guide))
      (if preview "CSA-PREVIEW" "01-GB-Grid"))
    (csast:insert space "Cao do" (csast:p base (caadr guide) (cadadr guide))
      (if preview "CSA-PREVIEW" "11-GB-Cao Do") 0.25
      (list (cons "%%P0.000" (csad:leveltext value))))))

;;; Rebar detailing draft from Excel BJ28:BJ41 and Z23:Z26.
;;; Plate joint anchors use BJ38 times each bar diameter; 30-degree/2d return hooks.
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

;;; Separate bodies; lengths are passed in model mm by the Excel anchor helper.
(defun csar:anchor-length (data diameter) (* (nth 10 data) diameter))
(defun csar:flight-axis (raw cover top)
  (if top
    (csar:offset (nth 2 raw) (nth 3 raw) (- 0.0 cover))
    (csar:offset (nth 14 raw) (nth 13 raw) cover)))

(defun csar:aty (a b y)
  (list (+ (car a) (* (- y (cadr a)) (/ (- (car b) (car a)) (- (cadr b) (cadr a))))) y))

(defun csar:support-beam (raw upper / left right bottom slab)
  ;; Inner downstand at each flight/landing junction, not the outer landing beam.
  (if upper
    (setq left (car (nth 11 raw)) right (car (nth 10 raw))
          bottom (cadr (nth 10 raw)) slab (cadr (nth 9 raw)))
    (setq left (car (nth 18 raw)) right (car (nth 17 raw))
          bottom (cadr (nth 18 raw)) slab (cadr (nth 19 raw))))
  (if (and (> (- right left) 0.5) (> (- slab bottom) 0.5))
    (list left right bottom slab)))

(defun csar:outer-support (raw upper / width depth)
  ;; End away from the inclined flight. An inner support is independent.
  (if upper
    (setq width (- (car (nth 6 raw)) (car (nth 7 raw)))
          depth (- (cadr (nth 8 raw)) (cadr (nth 7 raw))))
    (setq width (- (car (nth 21 raw)) (car (nth 22 raw)))
          depth (- (cadr (nth 20 raw)) (cadr (nth 21 raw)))))
  (and (> width 0.5) (> depth 0.5)))

(defun csar:landing-end (raw cover diameter upper top / body edge bottom)
  ;; Outer end: top returns to the lower-body axis, with or without an end beam.
  ;; Bottom ends at cover with a beam; a free end retains cover + 20 mm.
  (setq body (csar:landingline raw cover diameter upper top)
        edge (if upper (cadr body) (car body)))
  (if top
    (progn
      (setq bottom (csar:landingline raw cover diameter upper nil))
      (list (list (car edge) (cadar bottom)) edge))
    (if (csar:outer-support raw upper) (list edge)
      (list (list (+ (car edge) (if upper -20.0 20.0)) (cadr edge))))))

(defun csar:support-label (raw / lower upper)
  (if (/= (length raw) 24) "Beam supports: requires 24-row section data"
    (progn
      (setq lower (csar:support-beam raw nil) upper (csar:support-beam raw T))
      (strcat "Beam supports (Excel): "
        (cond ((and lower upper) "Lower + Upper") (lower "Lower only")
              (upper "Upper only") (T "None"))))))

(defun csar:joint-turn-at (raw cover upper flighttop axis y / direct middle x)
  (setq direct (csar:aty (car axis) (cadr axis) y)
        middle (csad:mid (car axis) (cadr axis)))
  (if (>= (csar:path-clearance (list direct middle) (csad:cleanpoints raw)) (- cover 0.01))
    (list direct direct)
    (progn
      (setq x (if upper
        (if flighttop (+ (car (nth 4 raw)) cover) (- (car (nth 10 raw)) cover))
        (if flighttop (+ (car (nth 1 raw)) cover) (- (car (nth 15 raw)) cover))))
      (list (list x y) (csar:atx (car axis) (cadr axis) x)))))

(defun csar:joint-turn (raw cover upper flighttop / axis landing y)
  (setq axis (csar:flight-axis raw cover flighttop)
        landing (csar:landingline raw cover 0 upper nil)
        y (+ (cadar landing) (if flighttop 10.0 0.0)))
  ;; Both flight tails reference the LOWER landing axis: top at +10, bottom at 0.
  (csar:joint-turn-at raw cover upper flighttop axis y))

(defun csar:hookpoint (previous tip diameter polygon / span dx dy leg c first second)
  (setq span (distance previous tip) dx (/ (- (car tip) (car previous)) span)
        dy (/ (- (cadr tip) (cadr previous)) span) leg (* 2.0 diameter)
        c 0.8660254037844386) ; cos(30 degrees), sin(30 degrees)=0.5
  (setq first (list (+ (car tip) (* leg (- (- 0.0 (* c dx)) (* 0.5 dy))))
                    (+ (cadr tip) (* leg (+ (- 0.0 (* c dy)) (* 0.5 dx)))))
        second (list (+ (car tip) (* leg (+ (- 0.0 (* c dx)) (* 0.5 dy))))
                     (+ (cadr tip) (* leg (- (- 0.0 (* c dy)) (* 0.5 dx))))))
  ;; Choose the inward-facing return. Never shorten the 2d tail to force a fit.
  (if (> (csar:path-clearance (list tip second) polygon)
         (csar:path-clearance (list tip first) polygon)) second first))

(defun csar:beam-leg (entry bend embedment-mm diameter direction polygon / remaining tip)
  ;; Length is developed INSIDE the support, from entry face; 2d is additional.
  ;; If the bend is in a neck ABOVE the beam, entry is later on the vertical
  ;; leg. The neck traversal is not part of the embedment-mm embedded in the beam.
  (setq remaining (if (and (< (abs (- (car entry) (car bend))) 0.000001)
                          (> (* direction (- (cadr entry) (cadr bend))) 0.0))
                    (+ embedment-mm (distance entry bend))
                    (- embedment-mm (distance entry bend))))
  (if (> remaining 0.001)
    (progn
      (setq tip (list (car bend) (+ (cadr bend) (* direction remaining))))
      (list (csar:hookpoint bend tip diameter polygon) tip bend))))

(defun csar:beam-entry (raw beam axis bend upper / point ceiling floor)
  (setq ceiling (cadr (nth (if upper 4 0) raw)) floor (nth 2 beam)
        point (csar:atx (car axis) (cadr axis) (nth (if upper 0 1) beam)))
  (cond ((> (cadr point) ceiling) (setq point (csar:aty (car axis) (cadr axis) ceiling)))
        ((< (cadr point) floor) (setq point (csar:aty (car axis) (cadr axis) floor))))
  (if (and (>= (car point) (car beam)) (<= (car point) (nth 1 beam))
           (if upper (<= (car point) (car bend)) (>= (car point) (car bend))))
    point
    ;; The inclined body has not reached the beam before bending in a neck.
    (list (car bend) (if upper floor ceiling))))

(defun csar:beam-flight-end (raw cover diameter embedment-mm upper top / beam axis entry bend path near polygon)
  (setq beam (csar:support-beam raw upper) axis (csar:flight-axis raw cover top)
        polygon (csad:cleanpoints raw)
        bend (csar:atx (car axis) (cadr axis)
               (if upper (- (nth 1 beam) cover) (+ (car beam) cover)))
        entry (csar:beam-entry raw beam axis bend upper)
        path (csar:beam-leg entry bend embedment-mm diameter (if upper 1.0 -1.0) polygon))
  ;; A tall lower neck can obstruct the far-face continuation. Its vertical
  ;; leg then follows the near cover face, still measuring from the beam entry.
  (if (and (not upper)
           (or (not path)
               (< (csar:path-clearance (append path (list (csad:mid (car axis) (cadr axis)))) polygon)
                  (- cover 0.01))))
    (progn
      (setq near (csar:atx (car axis) (cadr axis) (- (nth 1 beam) cover)))
      (setq entry (csar:beam-entry raw beam axis near upper)
            path (csar:beam-leg entry near embedment-mm diameter -1.0 polygon))))
  path)

(defun csar:main-end (raw cover diameter anchor-length upper top / beam joint tip polygon)
  (setq polygon (csad:cleanpoints raw))
  (if (setq beam (csar:support-beam raw upper))
    (csar:beam-flight-end raw cover diameter anchor-length upper top)
    (progn
      (setq joint (csar:joint-turn raw cover upper top)
            tip (list (+ (caar joint) (* (if upper 1.0 -1.0) anchor-length)) (cadar joint)))
      (list (csar:hookpoint (car joint) tip diameter polygon) tip (car joint) (cadr joint)))))

(defun csar:flight-fit-error (raw cover diameter embedment-mm top / issue upper path axis polygon)
  (setq axis (csar:flight-axis raw cover top) polygon (csad:cleanpoints raw))
  (foreach upper (list nil T)
    (setq path (csar:main-end raw cover diameter embedment-mm upper top))
    (if (and (not issue)
          (or (not path)
              (< (csar:path-clearance (append path (list (csad:mid (car axis) (cadr axis)))) polygon)
                 (- cover 0.01))))
      (setq issue (strcat (if upper "Upper" "Lower")
        (if (csar:support-beam raw upper) " beam" " plate joint")
        " / flight " (if top "top" "bottom") ": anchor " (rtos embedment-mm 2 1)
        " mm (BJ38 x d), plus 2d hook, does not fit cover. Check actual support size and BJ38; length was not shortened."))))
  issue)

(defun csar:mainpath (raw cover diameter anchor-length top / lower upper)
  (setq lower (csar:main-end raw cover diameter anchor-length nil top)
        upper (csar:main-end raw cover diameter anchor-length T top))
  (if (and lower upper) (csad:cleanpoints (append lower (reverse upper)))))

(defun csar:landingpath (raw cover diameter anchor-length upper top / axis joint edge knee tip polygon beam bend ending entry leg)
  (setq ending (csar:landing-end raw cover diameter upper top)
        edge (car (reverse ending)) polygon (csad:cleanpoints raw))
  (if (and (not top) (setq beam (csar:support-beam raw upper)))
    (progn
      ;; Landing lower bar enters from the landing side and turns down at
      ;; the opposite cover face. Include its horizontal entry in BJ38 x d.
      (setq entry (list (nth (if upper 1 0) beam) (cadr edge))
            bend (list (if upper (+ (car beam) cover) (- (nth 1 beam) cover)) (cadr edge))
            leg (csar:beam-leg entry bend anchor-length diameter -1.0 polygon))
      (if leg (csad:cleanpoints (append ending (reverse leg)))))
    (progn
      ;; Top landing tails follow a line 10 mm normal inside the lower flight axis.
      (setq axis (csar:flight-axis raw (+ cover (if top 10.0 0.0)) nil)
            joint (csar:joint-turn-at raw cover upper nil axis (cadr edge))
            knee (cadr joint)
            tip (csar:advance knee (csad:mid (car axis) (cadr axis)) anchor-length))
      (csad:cleanpoints (append ending (list (car joint) knee tip (csar:hookpoint knee tip diameter polygon)))))))

(defun csar:neck-height (raw upper)
  (if upper (- (cadr (nth 4 raw)) (cadr (nth 3 raw)))
            (- (cadr (nth 2 raw)) (cadr (nth 1 raw)))))

(defun csar:neck-enabled (raw upper)
  (and (> (csar:neck-height raw upper) 100.0) (not (csar:support-beam raw upper))))

(defun csar:neck-box (raw cover upper / inset)
  ;; Tie d8: outer face observes cover; centerline is cover + 4 mm.
  (setq inset (+ cover 4.0))
  (if upper
    (list (+ (car (nth 3 raw)) inset) (+ (cadr (nth 13 raw)) inset)
          (- (car (nth 9 raw)) inset) (- (cadr (nth 4 raw)) inset))
    (list (+ (car (nth 1 raw)) inset) (+ (cadr (nth 20 raw)) inset)
          (- (car (nth 14 raw)) inset) (- (cadr (nth 2 raw)) inset))))

(defun csar:box-path (box / left bottom right top)
  (setq left (nth 0 box) bottom (nth 1 box) right (nth 2 box) top (nth 3 box))
  (list (list left bottom) (list right bottom) (list right top) (list left top) (list left bottom)))

(defun csar:rounded-box (box radius / left bottom right top)
  (setq left (nth 0 box) bottom (nth 1 box) right (nth 2 box) top (nth 3 box))
  ;; CCW; vertices 1,3,5,7 start quarter-circle arcs (bulge tan(pi/8)).
  (list (list (+ left radius) bottom) (list (- right radius) bottom)
        (list right (+ bottom radius)) (list right (- top radius))
        (list (- right radius) top) (list (+ left radius) top)
        (list left (- top radius)) (list left (+ bottom radius))))

(defun csar:neck-dots (box / radius left bottom right top)
  ;; Four true d8 corner bars; the 1.5x display disks remain inside the tie box.
  (setq radius (/ (csar:display-diameter 8.0) 2.0)
        left (+ (nth 0 box) radius) bottom (+ (nth 1 box) radius)
        right (- (nth 2 box) radius) top (- (nth 3 box) radius))
  (list (list left bottom) (list right bottom) (list right top) (list left top)))

(defun csar:neck-error (raw cover / issue upper box polygon point)
  (setq polygon (csad:cleanpoints raw))
  (foreach upper (list nil T)
    (if (csar:neck-enabled raw upper)
      (progn
        (setq box (csar:neck-box raw cover upper))
        (if (or (< (- (nth 2 box) (nth 0 box)) 24.0)
                (< (- (nth 3 box) (nth 1 box)) 24.0)
                (< (csar:path-clearance (csar:box-path box) polygon) (- (+ cover 4.0) 0.01)))
          (setq issue (strcat (if upper "Upper" "Lower")
            " neck: d8 tie / four d8 corners do not fit actual neck width, height and cover."))))))
  issue)

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

(defun csar:display-diameter (diameter) (* 1.5 diameter))

(defun csar:distribution-line (raw cover main-d diameter top / line radius dx dy span)
  ;; Visual disk is tangent to the longitudinal axis: offset by displayed d/2.
  (setq radius (+ cover (/ (csar:display-diameter diameter) 2.0)))
  (if top
    (setq line (csar:offset (nth 2 raw) (nth 3 raw) (- 0.0 radius)))
    (setq line (csar:offset (nth 14 raw) (nth 13 raw) radius)))
  (setq span (distance (car line) (cadr line))
        dx (/ (- (caadr line) (caar line)) span)
        dy (/ (- (cadadr line) (cadar line)) span))
  (list (list (+ (caar line) (* radius dx)) (+ (cadar line) (* radius dy)))
        (list (- (caadr line) (* radius dx)) (- (cadadr line) (* radius dy)))))

(defun csar:landing-distribution-line (raw cover main-d diameter upper top)
  (csar:landingline raw (+ cover (/ (csar:display-diameter diameter) 2.0)) diameter upper top))

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
  (if (and (not issue) (<= (- (cadr (nth 3 raw)) (cadr (nth 2 raw))) 0.000001))
    (setq issue "Crossed joints require a positive inclined rise between STT 3 and 4."))
  (if (not issue)
    (cond
      ((/= (length data) 14) (setq issue "Reload Excel for reinforcement parameters BJ28:BJ41."))
      ((/= (length options) 7) (setq issue "Reload Excel for step counts and Z23:Z26 switches."))
      (T
        (setq cover (nth 0 data) layers (csar:layers data) firstmark (nth 11 data))
        (foreach value '(3 4 5 6)
          (if (null (csar:flag (nth value options)))
            (setq issue "Z23:Z26 must be Yes/No (landing bars and transverse dots).")))
        (foreach value (list cover (nth 1 data) (nth 3 data) firstmark (nth 12 data))
          (if (or (not (numberp value)) (and (numberp value) (<= value 0.0)))
            (setq issue "Cover, widths, first mark and member count must be positive.")))
        (if (and (numberp firstmark) (/= firstmark (fix firstmark)))
          (setq issue "First bar mark must be an integer."))
        (if (or (not (numberp (nth 10 data)))
                (and (numberp (nth 10 data)) (<= (nth 10 data) 0.0)))
          (setq issue "BJ38 anchor multiplier must be a positive number (for example 30 for 30d)."))
        (if (not layers) (setq issue "BJ37 must specify 1 or 2 reinforcement layers."))
        (foreach value '(4 5 6 7 8)
          (if (not (csar:bar (nth value data)))
            (setq issue "Use diameter/spacing such as 12a150 in BJ32:BJ36.")))
        (if (not issue)
          (progn
            (setq bottom (csar:bar (nth 6 data)) top (csar:bar (nth 7 data)))
            (foreach value (if (= layers 2) (list nil T) (list nil))
              (setq radius cover
                    path (csar:mainpath raw cover (car (if value top bottom)) (csar:anchor-length data (car (if value top bottom))) value))
              (if (not issue)
                (setq issue (csar:flight-fit-error raw cover (car (if value top bottom))
                  (csar:anchor-length data (car (if value top bottom))) value))))
            ;; Full paths intentionally cross at the joints. Check only body
            ;; axes for layer overlap; every hooked path is checked for cover.
            (if (and (= layers 2)
                     (< (csar:path-distance
                          (csar:flight-axis raw cover nil)
                          (csar:flight-axis raw cover T))
                        (/ (+ (car bottom) (car top)) 2.0)))
              (setq issue "Top and bottom flight body axes overlap. Check cover, diameters and support dimensions."))
            (foreach side (list nil T)
              (if (= 1 (csar:flag (nth (if side 3 4) options)))
                (progn
                  (setq bar (csar:bar (nth (if side 5 4) data)) radius cover)
                  (foreach value (if (= layers 2) (list nil T) (list nil))
                    (setq path (csar:landingpath raw cover (car bar) (csar:anchor-length data (car bar)) side value))
                    (if (and (not issue) (or (not path)
                          (< (csar:path-clearance path (csad:cleanpoints raw)) (- radius 0.01))))
                      (setq issue (strcat (if side "Upper" "Lower") " Landing "
                        (if value "top" "bottom") ": BJ38 x d = "
                        (rtos (csar:anchor-length data (car bar)) 2 1)
                        " mm plus 2d hook does not fit concrete/cover. Length was not shortened."))))
                  (if (and (= layers 2)
                           (< (csar:path-distance
                                (csar:landingline raw cover (car bar) side nil)
                                (csar:landingline raw cover (car bar) side T)) (car bar)))
                    (setq issue "Landing reinforcement layers overlap; check cover and diameter.")))))
            (if (not issue)
              (progn
                (setq bar (csar:bar (nth 8 data)) specs (csar:distribution-specs raw data options))
                (foreach spec specs
                  (setq line (nth 2 spec) radius (+ cover (/ (csar:display-diameter (car bar)) 2.0)))
                  (if (or (<= (distance (car line) (cadr line)) 0.001)
                          (> (/ (distance (car line) (cadr line)) (cadr bar)) 2000)
                          (< (csar:path-clearance line (csad:cleanpoints raw)) (- radius 0.01)))
                    (setq issue "Transverse bars do not fit cover, or exceed 2000 dots per region/layer. Check BJ36 and slab geometry."))
                  (foreach other specs
                    (if (and (= (car spec) (car other)) (not (eq (cadr spec) (cadr other)))
                             (< (csar:path-distance line (nth 2 other)) (csar:display-diameter (car bar))))
                      (setq issue "Top/bottom transverse bars overlap; check cover, diameters and slab thickness.")))))))))))
  (if (not issue) (setq issue (csar:neck-error raw (car data))))
  (if (not issue) (setq issue (csar:callout-error raw data options)))
  issue)

(defun csar:polyline (space base points layer / coords p array object remaining)
  (setq csad-stage "Rebar: create polyline")
  (foreach p points
    (setq coords (append coords (list (+ (car base) (car p)) (+ (cadr base) (cadr p))))))
  (setq array (vlax-make-safearray vlax-vbDouble (cons 0 (1- (length coords)))))
  (vlax-safearray-fill array coords)
  (setq object (csast:track (vla-AddLightWeightPolyline space array)))
  (vla-put-Layer object layer) (vla-put-Elevation object (caddr base))
  (vla-put-Closed object :vlax-false)
  (if (boundp 'csar-obstacles)
    (progn
      (setq remaining points)
      (while (cdr remaining)
        (setq csar-obstacles (cons (list "SEG"
          (csast:p base (caar remaining) (cadar remaining))
          (csast:p base (caadr remaining) (cadadr remaining))) csar-obstacles)
          remaining (cdr remaining)))))
  object)

(defun csar:dot (space base point diameter layer / object draw-diameter)
  ;; Visual disk is 1.5d; axis offset uses that visual radius, labels retain true d.
  ;; No hatch, block, POINT display mode, or global variable is required.
  (setq draw-diameter (csar:display-diameter diameter)
        object (csar:polyline space base
    (list (list (- (car point) (/ draw-diameter 4.0)) (cadr point))
          (list (+ (car point) (/ draw-diameter 4.0)) (cadr point))) layer))
  (setq csad-stage "Transverse dot: set bulges and width")
  (vla-put-Closed object :vlax-true)
  (vla-SetBulge object 0 1.0) (vla-SetBulge object 1 1.0)
  (vla-put-ConstantWidth object (/ draw-diameter 2.0))
  object)

(defun csar:leader-marker (space base target layer dotted size / object half)
  ;; Explicit model-space symbol avoids native LEADER auto-suppression and DIMTSZ.
  (if dotted
    (setq object (csast:track (vla-AddCircle space
      (vlax-3d-point (csast:p base (car target) (cadr target))) (/ size 2.0))))
    (progn
      (setq half (* size 0.3535533905932738)
            object (csar:polyline space base
              (list (list (- (car target) half) (+ (cadr target) half))
                    (list (+ (car target) half) (- (cadr target) half))) layer))
      (vla-put-ConstantWidth object (/ size 8.0))))
  (vla-put-Layer object layer)
  object)

(defun csar:leader (space base points layer dotted size style annotation / coords point array object)
  (foreach point points
    (setq coords (append coords (csast:p base (car point) (cadr point)))))
  (setq array (vlax-make-safearray vlax-vbDouble (cons 0 (1- (length coords)))))
  (vlax-safearray-fill array coords)
  ;; Annotation must be an existing CSA BlockReference, not a missing nil argument.
  ;; AcLeaderType: 0=line/no arrow, 1=spline/no arrow, 2=line/arrow, 3=spline/arrow.
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
  (setq csad-stage "Leader: restore perpendicular vertical and horizontal coordinates")
  (vla-put-Coordinates object array)
  (vla-put-Type object 0)
  (vla-Update object)
  (csar:leader-marker space base (car points) layer dotted size)
  object)

(defun csar:note-route (target low high textlow texthigh height / y far margin)
  ;; Horizontal leg under the diameter/spacing attribute, not through its center.
  ;; Vertical stem through the target, then a perpendicular horizontal shelf.
  (setq margin (max 10.0 (* 0.2 height)) y (- (cadr textlow) margin))
  (if (< (car target) (/ (+ (car textlow) (car texthigh)) 2.0))
    (setq far (car texthigh))
    (setq far (car textlow)))
  (list target (list (car target) y) (list far y)))

(defun csar:notation (bar choice)
  (if (nth 3 bar)
    (strcat (itoa (nth 3 bar)) (if (= choice "1") "T" "%%C") (rtos (car bar) 2 0))
    (strcat (if (= choice "1") "T" "%%C") (nth 2 bar))))

(defun csar:format-note (note value / attrs att textatt)
  ;; The CSA definition uses legacy VNI for DK-KC. Its glyph mapping can draw
  ;; %%C as an accent despite the correct TextString. Override only the NEW
  ;; DK-KC reference with the existing Arial style, then reapply the value.
  (setq attrs (vlax-invoke note 'GetAttributes))
  (foreach att attrs
    (if (= (strcase (vla-get-TagString att)) "DK-KC")
      (progn
        (vla-put-StyleName att "01-GB-Arial")
        (vla-put-TextString att value)
        (vla-Update att)
        (setq textatt att))))
  (vla-Update note)
  textatt)

(defun csar:reverse-note-shift (low texthigh height / gap)
  (setq gap (max 10.0 (* 0.2 height)))
  (list (- (car low) gap (car texthigh)) 0.0 0.0))

(defun csar:reverse-note (note textatt height / low high textlow texthigh delta)
  (vla-GetBoundingBox note 'low 'high)
  (vla-GetBoundingBox textatt 'textlow 'texthigh)
  (setq delta (csar:reverse-note-shift (vlax-safearray->list low)
                                      (vlax-safearray->list texthigh) height))
  (vla-Move textatt (vlax-3d-point '(0.0 0.0 0.0)) (vlax-3d-point delta))
  (vla-Update textatt) (vla-Update note))

(defun csar:note-shift (edge textlow destination height / margin)
  ;; destination = selected label edge / exact shelf level, never bbox center.
  (setq margin (max 10.0 (* 0.2 height)))
  (list (- (car destination) (car edge))
        (- (cadr destination) (- (cadr textlow) margin)) 0.0))

(defun csar:bbox (object / low high)
  (vla-GetBoundingBox object 'low 'high)
  (list (vlax-safearray->list low) (vlax-safearray->list high)))

(defun csar:collect-obstacles (space excluded / result object box kind coords points)
  (vlax-for object space
    (if (not (member (vlax-vla-object->ename object) excluded))
      (progn
        (setq box (vl-catch-all-apply 'csar:bbox (list object)))
        (if (not (vl-catch-all-error-p box))
          (progn
            (setq kind (vla-get-ObjectName object))
            (if (= kind "AcDbPolyline")
              (progn
                (setq coords (vlax-safearray->list (vlax-variant-value (vla-get-Coordinates object))) points nil)
                (while coords
                  (setq points (cons (list (car coords) (cadr coords)) points) coords (cddr coords)))
                (setq points (reverse points))
                (if (= (vla-get-Closed object) :vlax-true) (setq points (append points (list (car points)))))
                (while (cdr points)
                  (setq result (cons (list "SEG" (car points) (cadr points)) result) points (cdr points))))
              (if (= kind "AcDbLine")
                (setq result (cons (list "SEG"
                  (vlax-safearray->list (vlax-variant-value (vla-get-StartPoint object)))
                  (vlax-safearray->list (vlax-variant-value (vla-get-EndPoint object)))) result))
                (setq result (cons (cons "BOX" box) result)))))))))
  result)

(defun csar:add-path-obstacles (base points)
  (while (cdr points)
    (setq csar-obstacles (cons (list "SEG"
      (csast:p base (caar points) (cadar points))
      (csast:p base (caadr points) (cadadr points))) csar-obstacles)
      points (cdr points))))

(defun csar:plan-obstacles (base raw data options / top side bar spec dots point radius)
  ;; Include future reinforcement too, before any labels are positioned.
  (foreach top (if (= (csar:layers data) 2) (list nil T) (list nil))
    (setq bar (csar:bar (nth (if top 7 6) data)))
    (csar:add-path-obstacles base (csar:mainpath raw (car data) (car bar) (csar:anchor-length data (car bar)) top))
    (foreach side (list nil T)
      (if (= 1 (csar:flag (nth (if side 3 4) options)))
        (progn
          (setq bar (csar:bar (nth (if side 5 4) data)))
          (csar:add-path-obstacles base (csar:landingpath raw (car data) (car bar)
            (csar:anchor-length data (car bar)) side top))))))
  (setq bar (csar:bar (nth 8 data)) radius (/ (csar:display-diameter (car bar)) 2.0))
  (foreach spec (csar:distribution-specs raw data options)
    (foreach point (csar:stations (car (nth 2 spec)) (cadr (nth 2 spec)) (cadr bar))
      (setq csar-obstacles (cons (list "BOX"
        (csast:p base (- (car point) radius) (- (cadr point) radius))
        (csast:p base (+ (car point) radius) (+ (cadr point) radius))) csar-obstacles)))))

(defun csar:box-hit (low high obstacle margin / a b corners edges hit)
  (setq low (list (- (car low) margin) (- (cadr low) margin))
        high (list (+ (car high) margin) (+ (cadr high) margin))
        a (nth 1 obstacle) b (nth 2 obstacle))
  (if (= (car obstacle) "BOX")
    (and (<= (car low) (car b)) (>= (car high) (car a))
         (<= (cadr low) (cadr b)) (>= (cadr high) (cadr a)))
    (progn
      (setq corners (list low (list (car high) (cadr low)) high (list (car low) (cadr high)) low)
            hit (or (and (<= (car low) (car a)) (<= (car a) (car high))
                         (<= (cadr low) (cadr a)) (<= (cadr a) (cadr high)))
                    (and (<= (car low) (car b)) (<= (car b) (car high))
                         (<= (cadr low) (cadr b)) (<= (cadr b) (cadr high)))))
      (while (cdr corners)
        (if (inters a b (car corners) (cadr corners) T) (setq hit T))
        (setq corners (cdr corners)))
      hit)))

(defun csar:label-shift (low high target obstacles right / attempt dx dy movedlow movedhigh hit obstacle result step vertical)
  (setq attempt 0 step 200.0 vertical (if (> (cadr low) (cadr target)) 1.0 -1.0))
  (while (and (< attempt 80) (not result))
    ;; First keep the requested placement, then walk away in rows and columns.
    (setq dx (* (if right -1.0 1.0) (* (rem attempt 5) step))
          dy (* vertical (* (fix (/ attempt 5)) step))
          movedlow (list (+ (car low) dx) (+ (cadr low) dy))
          movedhigh (list (+ (car high) dx) (+ (cadr high) dy)) hit nil)
    (if (if right (<= (car movedlow) (+ (car target) 20.0))
                  (>= (car movedhigh) (- (car target) 20.0))) (setq hit T))
    (foreach obstacle obstacles
      (if (csar:box-hit movedlow movedhigh obstacle 20.0) (setq hit T)))
    (if (not hit) (setq result (list dx dy 0.0)))
    (setq attempt (1+ attempt)))
  result)

(defun csar:note (space base target point bar mark dotted preview height right / layer note low high textatt textlow texthigh route delta value shift)
  (setq csad-stage (strcat "Rebar mark " (itoa mark) ": insert CSA note block")
        value (csar:notation bar (csad:get 'barprefix))
        layer (if preview "CSA-PREVIEW" "20-GB-GC")
        note (csast:insert space "CSA_Sohieu-KCthep" (csast:p base (car point) (cadr point))
          layer 1.0 (list (cons "SH" (itoa mark)) (cons "DK-KC" value))))
  (setq csad-stage (strcat "Rebar mark " (itoa mark) ": Arial attribute / exact shelf placement")
        textatt (csar:format-note note value))
  (if right (csar:reverse-note note textatt height))
  (vla-GetBoundingBox note 'low 'high)
  (vla-GetBoundingBox textatt 'textlow 'texthigh)
  (setq delta (csar:note-shift (vlax-safearray->list (if right textlow texthigh)) (vlax-safearray->list textlow)
                             (csast:p base (car point) (cadr point)) height))
  (vla-Move note (vlax-3d-point '(0.0 0.0 0.0)) (vlax-3d-point delta))
  (vla-Update note)
  (vla-GetBoundingBox note 'low 'high)
  (vla-GetBoundingBox textatt 'textlow 'texthigh)
  (setq shift (csar:label-shift (vlax-safearray->list low) (vlax-safearray->list high)
    (csast:p base (car target) (cadr target)) csar-obstacles right))
  (if (not shift)
    (progn (princ "\nNo clear position found for rebar label; move surrounding geometry and retry.") (exit)))
  (vla-Move note (vlax-3d-point '(0.0 0.0 0.0)) (vlax-3d-point shift))
  (vla-Update note)
  (vla-GetBoundingBox note 'low 'high)
  (vla-GetBoundingBox textatt 'textlow 'texthigh)
  (setq csar-obstacles (cons (list "BOX" (vlax-safearray->list low) (vlax-safearray->list high)) csar-obstacles))
  (setq low (vlax-safearray->list low) high (vlax-safearray->list high)
        textlow (vlax-safearray->list textlow) texthigh (vlax-safearray->list texthigh)
        route (csar:note-route (csast:p base (car target) (cadr target)) low high textlow texthigh height)
        route (mapcar '(lambda (p) (list (- (car p) (car base)) (- (cadr p) (cadr base)))) route))
  (csar:leader space base route layer dotted
    (distof (csad:get (if dotted 'dotsize 'ticksize)) 2) (csad:get 'dimstyle) note)
  note)

(defun csar:point-path-distance (point path / result)
  (setq result 1.0e20)
  (while (cdr path)
    (setq result (min result (csar:point-segment-distance point (car path) (cadr path)))
          path (cdr path)))
  result)

(defun csar:callout-targets (raw data region top / cover transverse main axis line dots dot first second path)
  (setq cover (car data) transverse (csar:bar (nth 8 data)))
  (if (= region "FLIGHT")
    (setq main (csar:bar (nth (if top 7 6) data))
          axis (csar:flight-axis raw cover top)
          line (csar:distribution-line raw cover (car main) (car transverse) top)
          path (csar:mainpath raw cover (car main) (csar:anchor-length data (car main)) top))
    (setq main (csar:bar (nth (if (= region "UPPER") 5 4) data))
          axis (csar:landingline raw cover (car main) (= region "UPPER") top)
          line (csar:landing-distribution-line raw cover (car main) (car transverse) (= region "UPPER") top)
          path (csar:landingpath raw cover (car main) (csar:anchor-length data (car main)) (= region "UPPER") top)))
  (if (and (> (distance (car line) (cadr line)) 0.001)
           (<= (/ (distance (car line) (cadr line)) (cadr transverse)) 2000))
    (progn
      (setq dots (csar:stations (car line) (cadr line) (cadr transverse))
            dot (nth (fix (* (if (= region "FLIGHT") (if top 0.7 0.5) (if (= region "UPPER") 0.3 0.65))
                            (1- (length dots)))) dots)
            first (csar:atx (car axis) (cadr axis) (- (car dot) 50.0))
            second (csar:atx (car axis) (cadr axis) (+ (car dot) 50.0)))
      ;; The dot leader targets an actual dot; the tick targets the actual bar.
      ;; Preserve a true 50 mm horizontal separation, rather than offsetting a
      ;; leader tip away from its entity or moving the dot grid.
      (cond ((and (< (csar:point-segment-distance first (car axis) (cadr axis)) 0.01)
                  (< (csar:point-path-distance first path) 0.01)) (list first dot))
            ((and (< (csar:point-segment-distance second (car axis) (cadr axis)) 0.01)
                  (< (csar:point-path-distance second path) 0.01)) (list second dot))))))

(defun csar:note-position (pair top dotted right)
  ;; 200 mm from main target to first shelf; 200 mm between shelves.
  ;; Label right edges share a column, 100 mm clear of the nearer vertical stem.
  (list (if right (+ (max (caar pair) (caadr pair)) 100.0)
                  (- (min (caar pair) (caadr pair)) 100.0))
    (+ (cadar pair) (* (if top 1.0 -1.0) (if dotted 400.0 200.0)))))

(defun csar:callout-error (raw data options / issue region top enabled upper)
  (foreach region '("FLIGHT" "LOWER" "UPPER")
    (setq upper (= region "UPPER")
          enabled (or (= region "FLIGHT")
            (= 1 (csar:flag (nth (if upper 3 4) options)))
            (= 1 (csar:flag (nth (if upper 5 6) options)))))
    (if enabled
      (foreach top (if (= (csar:layers data) 2) (list nil T) (list nil))
        (if (not (csar:callout-targets raw data region top))
          (setq issue (strcat "Cannot place leader targets 50 mm apart on the bar and a real dot in " region ". Check the region length and spacing."))))))
  issue)

(defun csar:render-necks (space base raw cover mark preview height / upper box tie index dots point target shelf layer)
  (setq layer (if preview "CSA-PREVIEW" "18-GB-Reinf"))
  (foreach upper (list nil T)
    (if (csar:neck-enabled raw upper)
      (progn
        (setq box (csar:neck-box raw cover upper)
              tie (csar:polyline space base (csar:rounded-box box 4.0) layer))
        (vla-put-Closed tie :vlax-true)
        (foreach index '(1 3 5 7) (vla-SetBulge tie index 0.4142135623730950))
        (setq dots (csar:neck-dots box))
        (foreach point dots (csar:dot space base point 8.0 layer))
        (setq target (list (/ (+ (nth 0 box) (nth 2 box)) 2.0) (nth 1 box))
              shelf (list (if upper (+ (nth 2 box) 100.0) (- (nth 0 box) 100.0)) (- (nth 1 box) 200.0)))
        (csar:note space base target shelf '(8.0 200.0 "8a200") mark nil preview height upper)
        (setq mark (1+ mark) target (nth (if upper 1 0) dots)
              shelf (list (car shelf) (- (cadr shelf) 200.0)))
        (csar:note space base target shelf '(8.0 0.0 "8" 4) mark T preview height upper)
        (setq mark (1+ mark)))))
  mark)

(defun csar:render (space base raw data options preview gap height / cover layers top bar path mark a b side
                                                        midpoint normal point minx miny text spec line dots dot pair region)
  (setq cover (nth 0 data) layers (csar:layers data) mark (fix (nth 11 data))
        minx (apply 'min (mapcar 'car raw)) miny (apply 'min (mapcar 'cadr raw)))
  (foreach top (if (= layers 2) (list nil T) (list nil))
    (setq bar (csar:bar (nth (if top 7 6) data))
          path (csar:mainpath raw cover (car bar) (csar:anchor-length data (car bar)) top)
          pair (csar:callout-targets raw data "FLIGHT" top)
          midpoint (car pair) point (csar:note-position pair top nil (not top)))
    (csar:polyline space base path (if preview "CSA-PREVIEW" "18-GB-Reinf"))
    (csar:note space base midpoint point bar mark nil preview height (not top))
    (setq mark (1+ mark)))
  (foreach side (list nil T)
    (if (= 1 (csar:flag (nth (if side 3 4) options)))
      (progn
        (setq bar (csar:bar (nth (if side 5 4) data)))
        (foreach top (if (= layers 2) (list nil T) (list nil))
          (setq path (csar:landingpath raw cover (car bar) (csar:anchor-length data (car bar)) side top)
                region (if side "UPPER" "LOWER")
                pair (csar:callout-targets raw data region top)
                midpoint (car pair) point (csar:note-position pair top nil (not top)))
          (csar:polyline space base path (if preview "CSA-PREVIEW" "18-GB-Reinf"))
          (csar:note space base midpoint point bar mark nil preview height (not top))
          (setq mark (1+ mark))))))
  ;; One mark per distribution region/layer; displayed dots are 1.5 times BJ36.
  (setq bar (csar:bar (nth 8 data)))
  (foreach spec (csar:distribution-specs raw data options)
    (setq line (nth 2 spec) top (nth 1 spec)
          dots (csar:stations (car line) (cadr line) (cadr bar))
          pair (csar:callout-targets raw data (car spec) top)
          midpoint (cadr pair))
    (foreach dot dots (csar:dot space base dot (car bar) (if preview "CSA-PREVIEW" "18-GB-Reinf")))
    (setq point (csar:note-position pair top T (not top)))
    (csar:note space base midpoint point bar mark T preview height (not top))
    (setq mark (1+ mark)))
  (setq mark (csar:render-necks space base raw cover mark preview height))
  (setq text (strcat "REBAR DRAFT / COVER=" (rtos cover 2 0)
    " / ANCHORS=" (rtos (nth 10 data) 2 1) "d / FLIGHT TAILS: TOP=+10, BOTTOM=0 FROM LOWER LANDING / HOOK=30 deg, 2d"))
  (csast:text space text (csast:p base minx (- miny (* 5.0 gap))) height
    (if preview "CSA-PREVIEW" "20-GB-GC") "01-GB-Arial")
  (csast:text space "JOINT DETAIL DRAFT / BEND RADII AND FABRICATION SCHEDULE NOT GENERATED"
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

(defun csad:excel-folder (/ folder)
  (setq folder (getenv "CSA_STAIR_EXCEL_FOLDER"))
  (if (and folder (/= folder "")) (strcat folder "/") ""))

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
  (csad:put 'supportinfo (csar:support-label rawpoints))
  (csad:put 'rawpoints rawpoints)
  (csad:put 'concrete-parameters metadata)
  (csad:put 'points points)
  (csad:put 'path path)
  (setenv "CSA_STAIR_EXCEL_FOLDER" (vl-filename-directory path))
  (csad:put 'bottom (csad:fixed3 bottom))
  (csad:put 'top (csad:fixed3 (+ bottom (/ rise 1000.0))))
  (if (and (= (type title) 'STR) (/= title "")) (csad:put 'title title))
  (csad:put 'status (strcat (itoa rawcount) " Excel rows / " (itoa (length points))
    " vertices loaded. Reload after Excel changes."))
  (foreach ref (list cells sheet sheets book books excel)
    (if (= (type ref) 'VLA-OBJECT) (vlax-release-object ref)))
  T)

(defun csad:capture (/ key)
  (foreach key '("title" "section" "bottom" "top" "dims" "details" "levels" "symbol" "steps" "rebar" "titleheight" "dimgap" "dotsize" "ticksize" "barprefix")
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
          ": row { : popup_list { key = \"barprefix\"; label = \"Rebar symbol\"; width = 25; }"
          ": text { label = \"Joint: BJ38 x d / 30 deg / 2d hook\"; } }"
          ": boxed_row { label = \"Section options\";"
          ": toggle { key = \"dims\"; label = \"Overall width\"; }"
          ": toggle { key = \"details\"; label = \"Concrete details\"; }"
          ": toggle { key = \"levels\"; label = \"Elevations\"; }"
          ": toggle { key = \"symbol\"; label = \"Section symbol\"; } }"
          ": toggle { key = \"steps\"; label = \"Step count x tread in flight dimension\"; }"
          ": toggle { key = \"rebar\"; label = \"Rebar draft - bent landing anchors and transverse dots\"; }"
          ": text { label = \"Neck >100, no beam: d8a200 + 4d8 / R4 | Dots x1.5\"; }"
          ": text { key = \"supportinfo\"; width = 80; }"
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
          (foreach name '("title" "section" "bottom" "top" "dims" "details" "levels" "symbol" "steps" "rebar" "status" "titleheight" "dimgap" "dotsize" "ticksize" "barprefix" "supportinfo")
            (set_tile name (csad:get (read name))))
          (start_list "dimstyle") (foreach name csad-styles (add_list name)) (end_list)
          (setq index (vl-position (csad:get 'dimstyle) csad-styles))
          (if (null index) (setq index 0))
          (set_tile "dimstyle" (itoa index))
          (start_list "barprefix") (add_list "%%C (Diameter)") (add_list "T") (end_list)
          (set_tile "barprefix" (csad:get 'barprefix))
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
                            height titleheight gap specs spec ds p toppt bottom top need name issue entities csad-stage csad-dimensions csar-obstacles)
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
  (if (and (= "1" (csad:get 'rebar)) (not (member (csad:get 'barprefix) '("0" "1"))))
    (setq issue "Select a rebar symbol: %%C or T."))
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
      (if (= "1" (csad:get 'levels)) (setq need (append '("01-GB-Grid" "11-GB-Cao Do") need)))
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
            (if (and (= (car spec) "flight_run") (= "1" (csad:get 'steps)))
              (setq spec (append spec (list (csad:step-dim-text (csad:get 'rawpoints) (csad:get 'section-options))))))
            (csad:draw-spec space base spec (if preview layer "04-GB-Dim") (csad:get 'dimstyle))))
        (if (and (= "1" (csad:get 'steps)) (/= "1" (csad:get 'details)))
          (csad:draw-steps space base (csad:get 'rawpoints) (csad:get 'section-options) gap height preview))
        (setq csad-stage "Elevations: horizontal guides and Cao do blocks")
        (if (= "1" (csad:get 'levels))
          (csad:draw-levels space base (csad:get 'rawpoints) bottom top preview))
        (setq csad-stage "Rebar: start drawing")
        (if (= "1" (csad:get 'rebar))
          (progn
          (setq csar-obstacles (csar:collect-obstacles space old))
          (csar:plan-obstacles base (csad:get 'rawpoints) (csad:get 'rebar-data) (csad:get 'section-options))
          (csar:render space base (csad:get 'rawpoints) (csad:get 'rebar-data)
            (csad:get 'section-options) preview gap height)))
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
  (foreach entry '((details . "1") (titleheight . "200") (dimgap . "400") (rebar . "0") (steps . "1") (dotsize . "60") (ticksize . "100") (barprefix . "0") (supportinfo . "Beam supports: Auto from Excel (reload)"))
    (if (not (assoc (car entry) *csad-state*)) (csad:put (car entry) (cdr entry))))
  (setq action 1)
  (while (and action (/= action 0))
    (setq action (csad:dialog))
    (cond
      ((and action (= action 11))
        (if (setq path (getfiled "Select the workbook already open in Excel" (csad:excel-folder) "xlsm" 0))
          (csad:loadexcel path)))
      ((and action (= action 12)) (csad:render T) (setq action 0))
      ((and action (= action 13)) (csad:render nil) (setq action 0))
      ((and action (= action 14)) (csad:clean))))
  (princ "\nRun CSA_STAIR_DRAWING to reopen. Loaded coordinates are a snapshot; reload after Excel edits.")
  (princ))

(princ "\nCSA Stair rebar-detail v5.5.1 loaded. Run CSA_STAIR_DRAWING; reload Excel once.")
(princ)
