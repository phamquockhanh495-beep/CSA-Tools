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
