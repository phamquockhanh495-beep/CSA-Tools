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
  (setq radius (+ cover (/ diameter 2.0)) leg (* diameter anchor-d))
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
  (setq radius (+ cover (/ diameter 2.0)))
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
  ;; Transverse bars lie inside the longitudinal bars, not on the same axis.
  (setq radius (+ cover (/ diameter 2.0)))
  (if top
    (setq line (csar:offset (nth 2 raw) (nth 3 raw) (- 0.0 (+ radius main-d))))
    (setq line (csar:offset (nth 14 raw) (nth 13 raw) (+ radius main-d))))
  (setq span (distance (car line) (cadr line))
        dx (/ (- (caadr line) (caar line)) span)
        dy (/ (- (cadadr line) (cadar line)) span))
  (list (list (+ (caar line) (* radius dx)) (+ (cadar line) (* radius dy)))
        (list (- (caadr line) (* radius dx)) (- (cadadr line) (* radius dy)))))

(defun csar:landing-distribution-line (raw cover main-d diameter upper top)
  (csar:landingline raw (+ cover main-d) diameter upper top))

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
              (setq radius (+ cover (/ (car (if value top bottom)) 2.0))
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
                  (setq bar (csar:bar (nth (if side 5 4) data)) radius (+ cover (/ (car bar) 2.0)))
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

(defun csar:leader (space base points layer dotted height diameter style annotation / coords point array object)
  (foreach point points
    (setq coords (append coords (csast:p base (car point) (cadr point)))))
  (setq array (vlax-make-safearray vlax-vbDouble (cons 0 (1- (length coords)))))
  (vlax-safearray-fill array coords)
  ;; Annotation is a required IDispatch parameter. AutoLISP nil can be marshalled
  ;; as a missing argument, not a null dispatch, causing "Parameter not optional".
  ;; Pass the existing CSA BlockReference, an annotation type AddLeader supports.
  (setq csad-stage "Leader: AddLeader with CSA block annotation")
  (setq object (csast:track (vla-AddLeader space array annotation 1))) ; acLineWithArrow
  (setq csad-stage "Leader: set layer and DimStyle")
  (vla-put-Layer object layer) (vla-put-StyleName object style)
  (setq csad-stage "Leader: set ScaleFactor")
  (vla-put-ScaleFactor object 1.0)
  ;; AcDimArrowheadType: 12 = acArrowDotBlank, 4 = acArrowArchTick.
  (setq csad-stage "Leader: set ArrowheadType")
  (vla-put-ArrowheadType object (if dotted 12 4))
  (setq csad-stage "Leader: set ArrowheadSize")
  (vla-put-ArrowheadSize object (if dotted (max (* 2.0 diameter) (* 0.6 height)) (* 0.8 height)))
  (setq csad-stage "Leader: Update")
  (vla-Update object)
  object)

(defun csar:note (space base target point bar mark dotted preview height / layer note low high attach elbow)
  (setq csad-stage (strcat "Rebar mark " (itoa mark) ": insert CSA note block"))
  (setq layer (if preview "CSA-PREVIEW" "20-GB-GC")
        note (csast:insert space "CSA_Sohieu-KCthep" (csast:p base (car point) (cadr point))
          layer 1.0 (list (cons "SH" (itoa mark)) (cons "DK-KC" (strcat "%%C" (nth 2 bar))))))
  (setq csad-stage (strcat "Rebar mark " (itoa mark) ": center note / GetBoundingBox"))
  (csad:center note (csast:p base (car point) (cadr point)))
  (vla-GetBoundingBox note 'low 'high)
  (setq low (vlax-safearray->list low) high (vlax-safearray->list high)
        attach (list (- (if (< (car target) (car point)) (car low) (car high)) (car base)) (cadr point))
        elbow (list (+ (car attach) (* (if (< (car target) (car point)) -2.0 2.0) height)) (cadr attach)))
  (csar:leader space base (list target elbow attach) layer dotted height (car bar) (csad:get 'dimstyle) note)
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
