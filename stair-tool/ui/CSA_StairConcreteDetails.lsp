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
  (if (nth 5 spec) (vla-put-TextOverride obj (nth 5 spec)))
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
      (if preview "CSA-PREVIEW" "11-GB-Cao Do"))
    (csast:insert space "Cao do" (csast:p base (caadr guide) (cadadr guide))
      (if preview "CSA-PREVIEW" "11-GB-Cao Do") 0.25
      (list (cons "%%P0.000" (csad:leveltext value))))))
