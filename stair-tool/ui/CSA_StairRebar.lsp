;;; Rebar detailing draft from Excel BJ28:BJ41 and Z23:Z26.
;;; Joint legs are fixed 200 mm with 30-degree return hooks, 2d long; BJ38 is superseded.
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

;;; v5 joint: separate flight/landing bars weave into the opposite layer.
;;; Straight leg is fixed at 200 model mm; return hook is 2d at 30 degrees.
(defun csar:flight-axis (raw cover top)
  (if top
    (csar:offset (nth 2 raw) (nth 3 raw) (- 0.0 cover))
    (csar:offset (nth 14 raw) (nth 13 raw) cover)))

(defun csar:aty (a b y)
  (list (+ (car a) (* (- y (cadr a)) (/ (- (car b) (car a)) (- (cadr b) (cadr a))))) y))

(defun csar:joint-turn (raw cover upper flighttop / axis landing y direct middle x)
  (setq axis (csar:flight-axis raw cover flighttop)
        landing (csar:landingline raw cover 0 upper (not flighttop))
        y (cadar landing) direct (csar:aty (car axis) (cadr axis) y)
        middle (csad:mid (car axis) (cadr axis)))
  ;; At a continuous junction use the true line intersection, as in the sample.
  ;; A stepped concrete neck may make that extrapolation leave the concrete.
  (if (>= (csar:path-clearance (list direct middle) (csad:cleanpoints raw)) (- cover 0.01))
    (list direct direct)
    (progn
      (setq x (if upper
        (if flighttop (+ (car (nth 4 raw)) cover) (- (car (nth 10 raw)) cover))
        (if flighttop (+ (car (nth 1 raw)) cover) (- (car (nth 15 raw)) cover))))
      (list (list x y) (csar:atx (car axis) (cadr axis) x)))))

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

(defun csar:mainpath (raw cover diameter anchor-length top / lower upper lefttip righttip polygon)
  (setq lower (csar:joint-turn raw cover nil top) upper (csar:joint-turn raw cover T top)
        lefttip (list (- (caar lower) anchor-length) (cadar lower))
        righttip (list (+ (caar upper) anchor-length) (cadar upper))
        polygon (csad:cleanpoints raw))
  (csad:cleanpoints (list (csar:hookpoint (car lower) lefttip diameter polygon)
    lefttip (car lower) (cadr lower) (cadr upper) (car upper) righttip
    (csar:hookpoint (car upper) righttip diameter polygon))))

(defun csar:landingpath (raw cover diameter anchor-length upper top / axis joint edge knee tip polygon)
  (setq axis (csar:flight-axis raw cover (not top))
        joint (csar:joint-turn raw cover upper (not top))
        edge (csar:landingline raw cover diameter upper top)
        edge (if upper (cadr edge) (car edge)) knee (cadr joint)
        tip (csar:advance knee (csad:mid (car axis) (cadr axis)) anchor-length)
        polygon (csad:cleanpoints raw))
  (csad:cleanpoints (list edge (car joint) knee tip (csar:hookpoint knee tip diameter polygon))))

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
        (if (not layers) (setq issue "BJ37 must specify 1 or 2 reinforcement layers."))
        (foreach value '(4 5 6 7 8)
          (if (not (csar:bar (nth value data)))
            (setq issue "Use diameter/spacing such as 12a150 in BJ32:BJ36.")))
        (if (not issue)
          (progn
            (setq bottom (csar:bar (nth 6 data)) top (csar:bar (nth 7 data)))
            (foreach value (if (= layers 2) (list nil T) (list nil))
              (setq radius cover
                    path (csar:mainpath raw cover (car (if value top bottom)) 200.0 value))
              (if (< (csar:path-clearance path (csad:cleanpoints raw)) (- radius 0.01))
                (setq issue "Flight joint: 200 mm legs / 30-degree 2d hooks do not fit concrete/cover; no tail was shortened.")))
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
                    (setq path (csar:landingpath raw cover (car bar) 200.0 side value))
                    (if (< (csar:path-clearance path (csad:cleanpoints raw)) (- radius 0.01))
                      (setq issue "Landing joint: 200 mm leg / 30-degree 2d hook does not fit concrete/cover. Check BJ32/BJ33.")))
                  (if (and (= layers 2)
                           (< (csar:path-distance
                                (csar:landingline raw cover (car bar) side nil)
                                (csar:landingline raw cover (car bar) side T)) (car bar)))
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
  (if (not issue) (setq issue (csar:callout-error raw data options)))
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

(defun csar:dot (space base point diameter layer / object draw-diameter)
  ;; Visual disk is 1.5d; center, spacing, clearance inputs and labels retain true d.
  ;; No hatch, block, POINT display mode, or global variable is required.
  (setq draw-diameter (* 1.5 diameter)
        object (csar:polyline space base
    (list (list (- (car point) (/ draw-diameter 4.0)) (cadr point))
          (list (+ (car point) (/ draw-diameter 4.0)) (cadr point))) layer))
  (setq csad-stage "Transverse dot: set bulges and width")
  (vla-put-Closed object :vlax-true)
  (vla-SetBulge object 0 1.0) (vla-SetBulge object 1 1.0)
  (vla-put-ConstantWidth object (/ draw-diameter 2.0))
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
  (setq csad-stage "Leader: restore perpendicular vertical and horizontal coordinates")
  (vla-put-Coordinates object array)
  (vla-Update object)
  object)

(defun csar:note-route (target low high textlow texthigh height / y far margin)
  ;; Horizontal leg under the diameter/spacing attribute, not through its center.
  ;; Vertical stem through the target, then a perpendicular horizontal shelf.
  (setq margin (max 10.0 (* 0.2 height)) y (- (cadr textlow) margin))
  (if (< (car target) (/ (+ (car low) (car high)) 2.0))
    (setq far (car texthigh))
    (setq far (car textlow)))
  (list target (list (car target) y) (list far y)))

(defun csar:notation (bar choice)
  (strcat (if (= choice "1") "T" "%%C") (nth 2 bar)))

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

(defun csar:note-shift (high textlow destination height / margin)
  ;; destination = right edge of label / exact leader shelf level, not bbox center.
  (setq margin (max 10.0 (* 0.2 height)))
  (list (- (car destination) (car high))
        (- (cadr destination) (- (cadr textlow) margin)) 0.0))

(defun csar:note (space base target point bar mark dotted preview height / layer note low high textatt textlow texthigh route delta value)
  (setq csad-stage (strcat "Rebar mark " (itoa mark) ": insert CSA note block")
        value (csar:notation bar (csad:get 'barprefix))
        layer (if preview "CSA-PREVIEW" "20-GB-GC")
        note (csast:insert space "CSA_Sohieu-KCthep" (csast:p base (car point) (cadr point))
          layer 1.0 (list (cons "SH" (itoa mark)) (cons "DK-KC" value))))
  (setq csad-stage (strcat "Rebar mark " (itoa mark) ": Arial attribute / exact shelf placement")
        textatt (csar:format-note note value))
  (vla-GetBoundingBox note 'low 'high)
  (vla-GetBoundingBox textatt 'textlow 'texthigh)
  (setq delta (csar:note-shift (vlax-safearray->list high) (vlax-safearray->list textlow)
                             (csast:p base (car point) (cadr point)) height))
  (vla-Move note (vlax-3d-point '(0.0 0.0 0.0)) (vlax-3d-point delta))
  (vla-Update note)
  (vla-GetBoundingBox note 'low 'high)
  (vla-GetBoundingBox textatt 'textlow 'texthigh)
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
          path (csar:mainpath raw cover (car main) 200.0 top))
    (setq main (csar:bar (nth (if (= region "UPPER") 5 4) data))
          axis (csar:landingline raw cover (car main) (= region "UPPER") top)
          line (csar:landing-distribution-line raw cover (car main) (car transverse) (= region "UPPER") top)
          path (csar:landingpath raw cover (car main) 200.0 (= region "UPPER") top)))
  (if (and (> (distance (car line) (cadr line)) 0.001)
           (<= (/ (distance (car line) (cadr line)) (cadr transverse)) 2000))
    (progn
      (setq dots (csar:stations (car line) (cadr line) (cadr transverse))
            dot (nth (fix (* (if (= region "FLIGHT") (if top 0.7 0.5) 0.8)
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

(defun csar:note-position (pair top dotted)
  ;; 200 mm from main target to first shelf; 200 mm between shelves.
  ;; Label right edges share a column, 100 mm clear of the nearer vertical stem.
  (list (- (min (caar pair) (caadr pair)) 100.0)
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

(defun csar:render (space base raw data options preview gap height / cover layers top bar path mark a b side
                                                        midpoint normal point minx miny text spec line dots dot pair region)
  (setq cover (nth 0 data) layers (csar:layers data) mark (fix (nth 11 data))
        minx (apply 'min (mapcar 'car raw)) miny (apply 'min (mapcar 'cadr raw)))
  (foreach top (if (= layers 2) (list nil T) (list nil))
    (setq bar (csar:bar (nth (if top 7 6) data))
          path (csar:mainpath raw cover (car bar) 200.0 top)
          pair (csar:callout-targets raw data "FLIGHT" top)
          midpoint (car pair) point (csar:note-position pair top nil))
    (csar:polyline space base path (if preview "CSA-PREVIEW" "18-GB-Reinf"))
    (csar:note space base midpoint point bar mark nil preview height)
    (setq mark (1+ mark)))
  (foreach side (list nil T)
    (if (= 1 (csar:flag (nth (if side 3 4) options)))
      (progn
        (setq bar (csar:bar (nth (if side 5 4) data)))
        (foreach top (if (= layers 2) (list nil T) (list nil))
          (setq path (csar:landingpath raw cover (car bar) 200.0 side top)
                region (if side "UPPER" "LOWER")
                pair (csar:callout-targets raw data region top)
                midpoint (car pair) point (csar:note-position pair top nil))
          (csar:polyline space base path (if preview "CSA-PREVIEW" "18-GB-Reinf"))
          (csar:note space base midpoint point bar mark nil preview height)
          (setq mark (1+ mark))))))
  ;; One mark per distribution region/layer, every dot has the actual BJ36 diameter.
  (setq bar (csar:bar (nth 8 data)))
  (foreach spec (csar:distribution-specs raw data options)
    (setq line (nth 2 spec) top (nth 1 spec)
          dots (csar:stations (car line) (cadr line) (cadr bar))
          pair (csar:callout-targets raw data (car spec) top)
          midpoint (cadr pair))
    (foreach dot dots (csar:dot space base dot (car bar) (if preview "CSA-PREVIEW" "18-GB-Reinf")))
    (setq point (csar:note-position pair top T))
    (csar:note space base midpoint point bar mark T preview height)
    (setq mark (1+ mark)))
  (setq text (strcat "REBAR DRAFT / COVER=" (rtos cover 2 0)
    " / JOINT LEGS=200 mm / RETURN HOOK=30 deg, 2d"))
  (csast:text space text (csast:p base minx (- miny (* 5.0 gap))) height
    (if preview "CSA-PREVIEW" "20-GB-GC") "01-GB-Arial")
  (csast:text space "CROSSED JOINTS IN SECTION / BEND RADII AND FABRICATION SCHEDULE NOT GENERATED"
    (csast:p base minx (- miny (* 5.0 gap) (* 2.0 height))) height
    (if preview "CSA-PREVIEW" "20-GB-GC") "01-GB-Arial"))
