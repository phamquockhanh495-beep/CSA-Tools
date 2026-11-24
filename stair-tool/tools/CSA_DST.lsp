;;; Quick AutoCAD command alias for CSA Stair Drawing (VBA)
;;; APPLOAD this file (or add to Startup Suite alongside CSA_Staicase.dvb)
;;; then type DST on the AutoCAD command line to open the Stair Drawing UI.

(defun csast:find-dvb (/ p)
  (foreach p (list
               (findfile "CSA_Staicase.dvb")
               (findfile "CSA_Staircase.dvb"))
    (if p p)))

(defun c:DST (/ dvb)
  (if (vl-catch-all-error-p (vl-catch-all-apply 'vl-vbarun (list "DST")))
    (progn
      (setq dvb (or (findfile "CSA_Staicase.dvb") (findfile "CSA_Staircase.dvb")))
      (if dvb
        (progn
          (vl-vbaload dvb)
          (vl-vbarun "DST"))
        (princ "\nCSA_Staicase.dvb is not loaded. Run APPLOAD/VBALOAD to load CSA_Staicase.dvb first."))))
  (princ))

(princ "\nCSA Stair Tools loaded. Type DST to open Stair Drawing.")
(princ)
